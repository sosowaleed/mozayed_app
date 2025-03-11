/* eslint-disable */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';


// Do NOT call admin.initializeApp() here—this is done in index.ts.


// Configure your email transporter using environment configuration.
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// This function triggers when a new order document is created.
export const onNewOrder = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const orderData = event.data?.data();
    if (!orderData) return null;

    // Get buyer information.
    const buyerId = orderData.userId;
    const buyerDoc = await admin.firestore().collection('users').doc(buyerId).get();
    const buyerData = buyerDoc.data();
    if (!buyerData) {
      console.error(`No buyer data for userId: ${buyerId}`);
      return null;
    }
    const buyerEmail = buyerData.email;
    const buyerName = buyerData.name || 'A buyer';

    // Initialize email content for buyer.
    let buyerMessage = 'Thank you for your purchase! Here is the contact info for the sellers:\n\n';

    // Create a map to hold seller notifications.
    const sellerNotifications: { [sellerId: string]: { sellerEmail: string, items: string[] } } = {};

    // The orderData should have an "items" field that is an array of objects with a "listingId" property.
    const items = orderData.items as Array<{ listingId: string, quantity: number }>;
    for (const item of items) {
      const listingId = item.listingId;
      // Get the listing details.
      const listingDoc = await admin.firestore().collection('listings').doc(listingId).get();
      if (!listingDoc.exists) continue;
      const listingData = listingDoc.data();
      if (!listingData) continue;

      const itemName = listingData.title;
      const sellerId = listingData.ownerId;

      // Look up the seller email if not already cached.
      let sellerEmail = '';
      if (!sellerNotifications[sellerId]) {
        const sellerDoc = await admin.firestore().collection('users').doc(sellerId).get();
        const sellerData = sellerDoc.data();
        sellerEmail = sellerData?.email || 'unknown@example.com';
        sellerNotifications[sellerId] = { sellerEmail, items: [] };
      } else {
        sellerEmail = sellerNotifications[sellerId].sellerEmail;
      }
      // Append item info to the buyer's message.
      buyerMessage += `${itemName}: Contact seller at ${sellerEmail}\n`;

      // Append info for the seller.
      sellerNotifications[sellerId].items.push(`${itemName} (Qty: ${item.quantity}) purchased by ${buyerName} (${buyerEmail})`);
    }

    // Send email to buyer.
    if (buyerEmail) {
      const mailOptionsBuyer = {
        from: process.env.EMAIL_USER,
        to: buyerEmail,
        subject: 'Your Purchase Order Details',
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
      const sellerEmail = sellerInfo.sellerEmail;
      let sellerMessage = 'The following items of yours were purchased:\n\n';
      sellerInfo.items.forEach(itemInfo => {
        sellerMessage += `${itemInfo}\n`;
      });
      const mailOptionsSeller = {
        from: process.env.EMAIL_USER,
        to: sellerEmail,
        subject: 'Your Items Have Been Purchased',
        text: sellerMessage,
      };
      try {
        await transporter.sendMail(mailOptionsSeller);
        console.log(`Email sent to seller: ${sellerEmail}`);
      } catch (error) {
        console.error(`Error sending email to seller: ${error}`);
      }
    }
    return null;
  }
);
