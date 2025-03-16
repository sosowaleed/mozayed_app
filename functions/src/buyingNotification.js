const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");


// Configure your email transporter using functions.config()
// (You must set these using the Firebase CLI)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// Cloud Function triggered when a new order document is created.
exports.onNewOrder = onDocumentCreated(
  { document: "orders/{orderId}" },
  async (event, _context) => {
    const snap = event.data;
    if (!snap) {
      console.log("No data in snapshot.");
      return;
    }
    const orderData = snap.data();
    if (!orderData) return;

    // Get buyer information.
    const buyerId = orderData.userId;
    const buyerDoc = await admin.firestore().collection("users").doc(buyerId).get();
    const buyerData = buyerDoc.data();
    if (!buyerData) {
      console.error(`No buyer data for userId: ${buyerId}`);
      return;
    }
    const buyerEmail = buyerData.email;
    const buyerName = buyerData.name || "A buyer";

    // Extract shipping address (if provided).
    const shippingAddress = orderData.shippingAddress || "Shipping address not provided.";

    // Build email content for the buyer.
    let buyerMessage =
      "Thank you for your purchase! Here is the contact info for the sellers:\n\n";

    // Prepare a map to hold seller notifications.
    const sellerNotifications = {};

    // The orderData.items should be an array of objects with a listingId and quantity.
    const items = orderData.items;
    for (const item of items) {
      const listingId = item.listingId;
      const listingDoc = await admin.firestore().collection("listings").doc(listingId).get();
      if (!listingDoc.exists) continue;
      const listingData = listingDoc.data();
      if (!listingData) continue;

      const itemName = listingData.title;
      const sellerId = listingData.ownerId;

      // Cache seller info if not already fetched.
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

    // Append shipping address info to the buyer's message.
    buyerMessage += `\nYour Shipping Address: ${shippingAddress}\n`;

    // Send email to the buyer.
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
        sellerMessage += itemInfo + "\n";
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
    return;
  }
);
