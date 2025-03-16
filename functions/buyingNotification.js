const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize admin once (if not already done in your entry point)
admin.initializeApp();

// Configure the email transporter using functions.config() (make sure to set these)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().email.user,  // Set with: firebase functions:config:set email.user="your-email"
    pass: functions.config().email.pass,  // Set with: firebase functions:config:set email.pass="your-password"
  },
});

// This HTTP function will process new orders
exports.processNewOrders = functions.https.onRequest(async (req, res) => {
  try {
    // Query orders that haven't been processed (for example, where emailSent != true)
    const ordersSnapshot = await admin.firestore()
      .collection("orders")
      .where("emailSent", "==", false)
      .get();

    if (ordersSnapshot.empty) {
      console.log("No new orders to process.");
      res.status(200).send("No new orders.");
      return;
    }

    // Loop through each order and process it.
    const processPromises = ordersSnapshot.docs.map(async (doc) => {
      const orderData = doc.data();

      // Get buyer info from orderData
      const buyerId = orderData.userId;
      const buyerDoc = await admin.firestore().collection("users").doc(buyerId).get();
      const buyerData = buyerDoc.data();
      if (!buyerData) {
        console.error(`No buyer data for userId: ${buyerId}`);
        return;
      }
      const buyerEmail = buyerData.email;
      const buyerName = buyerData.name || "A buyer";

      // Get shipping address (if provided)
      const shippingAddress = orderData.shippingAddress || "Shipping address not provided.";

      // Build buyer email message
      let buyerMessage = "Thank you for your purchase! Here is the contact info for the sellers:\n\n";

      // Prepare a map to hold seller notifications.
      const sellerNotifications = {};

      // Expect orderData.items to be an array of objects (each with listingId, quantity)
      const items = orderData.items;
      for (const item of items) {
        const listingId = item.listingId;
        // Get listing details
        const listingDoc = await admin.firestore().collection("listings").doc(listingId).get();
        if (!listingDoc.exists) continue;
        const listingData = listingDoc.data();
        if (!listingData) continue;
        const itemName = listingData.title;
        const sellerId = listingData.ownerId;

        // Retrieve seller email if not cached.
        let sellerEmail = "";
        if (!sellerNotifications[sellerId]) {
          const sellerDoc = await admin.firestore().collection("users").doc(sellerId).get();
          const sellerData = sellerDoc.data();
          sellerEmail = sellerData && sellerData.email ? sellerData.email : "unknown@example.com";
          sellerNotifications[sellerId] = { sellerEmail, items: [] };
        } else {
          sellerEmail = sellerNotifications[sellerId].sellerEmail;
        }
        buyerMessage += `${itemName}: Contact seller at ${sellerEmail}\n`;
        sellerNotifications[sellerId].items.push(
          `${itemName} (Qty: ${item.quantity}) purchased by ${buyerName} (${buyerEmail})`
        );
      }

      buyerMessage += `\nYour Shipping Address: ${shippingAddress}\n`;

      // Send email to buyer.
      if (buyerEmail) {
        const mailOptionsBuyer = {
          from: functions.config().email.user,
          to: buyerEmail,
          subject: "Your Purchase Order Details",
          text: buyerMessage,
        };
        try {
          await transporter.sendMail(mailOptionsBuyer);
          console.log(`Email sent to buyer: ${buyerEmail}`);
        } catch (error) {
          console.error(`Error sending email to buyer: ${error}`);
        }
      }

      // Send email to each seller.
      for (const sellerId in sellerNotifications) {
        const sellerInfo = sellerNotifications[sellerId];
        let sellerMessage = "The following items of yours were purchased:\n\n";
        sellerInfo.items.forEach(itemInfo => {
          sellerMessage += `${itemInfo}\n`;
        });
        sellerMessage += `\nBuyer's Shipping Address: ${shippingAddress}\n`;
        const mailOptionsSeller = {
          from: functions.config().email.user,
          to: sellerInfo.sellerEmail,
          subject: "Your Items Have Been Purchased",
          text: sellerMessage,
        };
        try {
          await transporter.sendMail(mailOptionsSeller);
          console.log(`Email sent to seller: ${sellerInfo.sellerEmail}`);
        } catch (error) {
          console.error(`Error sending email to seller: ${error}`);
        }
      }

      // Mark this order as processed.
      await doc.ref.update({ emailSent: true });
    });

    await Promise.all(processPromises);
    res.status(200).send("Processed orders successfully.");
  } catch (error) {
    console.error("Error processing orders:", error);
    res.status(500).send("Error processing orders.");
  }
});
