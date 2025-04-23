
// Import Firebase Scheduler functions and Firebase Admin SDK.
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Do not call admin.initializeApp() here—initialize it once in your entry point (e.g. in index.js)

// Configure your email transporter using environment variables.
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER, // Email address for sending emails.
    pass: process.env.EMAIL_PASS, // Password for the email account.
  },
});

// Cloud Function triggered every 24 hours to finalize bids.
exports.finalizeBidListings = onSchedule("every 24 hours", async (_event) => {
  const now = new Date();
  const nowIso = now.toISOString(); // Get the current time in ISO format.
  const bidsRef = admin.firestore().collection("bids"); // Reference to the "bids" collection.

  // Query bid documents where bidFinalized is false and bidEndTime has passed.
  const snapshot = await bidsRef
    .where("bidFinalized", "==", false)
    .where("bidEndTime", "<=", nowIso)
    .get();

  // Process each bid document that matches the query.
  const promises = snapshot.docs.map(async (doc) => {
    const bidData = doc.data(); // Get bid data.
    const listingId = bidData.listingId; // ID of the associated listing.
    const sellerId = bidData.ownerId; // Seller's ID stored in the bid document.

    // Finalize the bid by updating the bidFinalized field.
    await doc.ref.update({ bidFinalized: true });

    // Remove the corresponding listing from the "listings" collection.
    await admin.firestore().collection("listings").doc(listingId).delete();

    // Get the highest bidder's ID.
    const highestBidderId = bidData.currentHighestBidderId;

    // Fetch seller data from the "users" collection.
    const sellerDoc = await admin.firestore().collection("users").doc(sellerId).get();
    const sellerData = sellerDoc.data();
    const sellerEmail = sellerData && sellerData.email ? sellerData.email : "unknown@example.com"; // Default to unknown email if not found.
    const sellerName = sellerData && sellerData.name ? sellerData.name : "Seller"; // Default to "Seller" if name is not found.

    // If there is a highest bidder, fetch their data.
    if (highestBidderId) {
      const bidderDoc = await admin.firestore().collection("users").doc(highestBidderId).get();
      const bidderData = bidderDoc.data();
      const bidderEmail = bidderData && bidderData.email ? bidderData.email : "unknown@example.com"; // Default to unknown email if not found.
      const bidderName = bidderData && bidderData.name ? bidderData.name : "Bidder"; // Default to "Bidder" if name is not found.

      // Build email messages for the seller and the highest bidder.
      const mailOptionsSeller = {
        from: process.env.EMAIL_USER,
        to: sellerEmail,
        subject: "Your Listing Bid Has Ended",
        text: `Hello ${sellerName},\n\nYour listing (${listingId}) bidding period has ended.\nThe winning bidder is:\nName: ${bidderName}\nEmail: ${bidderEmail}\n\nPlease contact them for the next steps.`,
      };

      const mailOptionsBidder = {
        from: process.env.EMAIL_USER,
        to: bidderEmail,
        subject: "Congratulations, You Won the Bid!",
        text: `Hello ${bidderName},\n\nCongratulations! Your bid on listing (${listingId}) has won.\n\nThe seller's contact details are:\nName: ${sellerName}\nEmail: ${sellerEmail}\n\nPlease contact the seller to proceed.`,
      };

      try {
        // Send emails to the seller and the highest bidder.
        await transporter.sendMail(mailOptionsSeller);
        await transporter.sendMail(mailOptionsBidder);
        console.log(`Emails sent for listing ${listingId}`);
      } catch (error) {
        console.error(`Error sending emails for listing ${listingId}:`, error);
      }
    }
  });

  // Wait for all promises to complete.
  await Promise.all(promises);
  console.log("Bid finalization complete.");
});
