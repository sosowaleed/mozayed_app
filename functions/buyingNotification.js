
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Configure the email transporter using Firebase Functions config
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().email.user,  // Email address configured in Firebase Functions environment
    pass: functions.config().email.pass,  // Email password configured in Firebase Functions environment
  },
});

// Cloud Function to process new orders and send notifications
exports.processNewOrders = functions.https.onRequest(async (req, res) => {
  try {
    // Query Firestore for orders that haven't been processed (emailSent == false)
    const ordersSnapshot = await admin.firestore()
      .collection("orders")
      .where("emailSent", "==", false)
      .get();

    // If no unprocessed orders are found, return early
    if (ordersSnapshot.empty) {
      console.log("No new orders to process.");
      res.status(200).send("No new orders.");
      return;
    }

    // Process each unprocessed order
    const processPromises = ordersSnapshot.docs.map(async (doc) => {
      const orderData = doc.data();

      // Retrieve buyer information from Firestore
      const buyerId = orderData.userId;
      const buyerDoc = await admin.firestore().collection("users").doc(buyerId).get();
      const buyerData = buyerDoc.data();
      if (!buyerData) {
        console.error(`No buyer data for userId: ${buyerId}`);
        return;
      }
      const buyerEmail = buyerData.email;
      const buyerName = buyerData.name || "A buyer";

      // Retrieve shipping address or use a default message
      const shippingAddress = orderData.shippingAddress || "Shipping address not provided.";

      // Initialize the buyer's email message
      let buyerMessage = "Thank you for your purchase! Here is the contact info for the sellers:\n\n";

      // Map to store notifications for each seller
      const sellerNotifications = {};

      // Process each item in the order
      const items = orderData.items;
      for (const item of items) {
        const listingId = item.listingId;

        // Retrieve listing details from Firestore
        const listingDoc = await admin.firestore().collection("listings").doc(listingId).get();
        if (!listingDoc.exists) continue;
        const listingData = listingDoc.data();
        if (!listingData) continue;

        const itemName = listingData.title;
        const sellerId = listingData.ownerId;

        // Retrieve seller email if not already cached
        let sellerEmail = "";
        if (!sellerNotifications[sellerId]) {
          const sellerDoc = await admin.firestore().collection("users").doc(sellerId).get();
          const sellerData = sellerDoc.data();
          sellerEmail = sellerData && sellerData.email ? sellerData.email : "unknown@example.com";
          sellerNotifications[sellerId] = { sellerEmail, items: [] };
        } else {
          sellerEmail = sellerNotifications[sellerId].sellerEmail;
        }

        // Add item details to the buyer's email message
        buyerMessage += `${itemName}: Contact seller at ${sellerEmail}\n`;

        // Add item details to the seller's notification
        sellerNotifications[sellerId].items.push(
          `${itemName} (Qty: ${item.quantity}) purchased by ${buyerName} (${buyerEmail})`
        );
      }

      // Add shipping address to the buyer's email message
      buyerMessage += `\nYour Shipping Address: ${shippingAddress}\n`;

      // Send email to the buyer
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

      // Send email notifications to each seller
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

      // Mark the order as processed by updating the emailSent field
      await doc.ref.update({ emailSent: true });
    });

    // Wait for all orders to be processed
    await Promise.all(processPromises);
    res.status(200).send("Processed orders successfully.");
  } catch (error) {
    // Log and return an error response if something goes wrong
    console.error("Error processing orders:", error);
    res.status(500).send("Error processing orders.");
  }
});
