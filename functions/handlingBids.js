const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Do not call admin.initializeApp() here—initialize it once in your entry point (e.g. in index.js)

// Configure your email transporter using environment variables.
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER, // or use functions.config().email.user if you prefer
    pass: process.env.EMAIL_PASS, // or use functions.config().email.pass
  },
});
// Cloud Function triggered every 24 hours to finalize bids.
exports.finalizeBidListings = onSchedule("every 24 hours", async (_event) => {
  const now = new Date();
  const nowIso = now.toISOString();
  const bidsRef = admin.firestore().collection("bids");

  // Query bid documents where bidFinalized is false and bidEndTime has passed.
  const snapshot = await bidsRef
    .where("bidFinalized", "==", false)
    .where("bidEndTime", "<=", nowIso)
    .get();

  const promises = snapshot.docs.map(async (doc) => {
    const bidData = doc.data();
    const listingId = bidData.listingId;
    const sellerId = bidData.ownerId; // seller's id stored in the bid document

    // Finalize the bid.
    await doc.ref.update({ bidFinalized: true });

    // Remove the corresponding listing from the "listings" collection.
    await admin.firestore().collection("listings").doc(listingId).delete();

    // Get the highest bidder's id.
    const highestBidderId = bidData.currentHighestBidderId;

    // Fetch seller data.
    const sellerDoc = await admin.firestore().collection("users").doc(sellerId).get();
    const sellerData = sellerDoc.data();
    const sellerEmail = sellerData && sellerData.email ? sellerData.email : "unknown@example.com";
    const sellerName = sellerData && sellerData.name ? sellerData.name : "Seller";

    // If there is a highest bidder, fetch their data.
    if (highestBidderId) {
      const bidderDoc = await admin.firestore().collection("users").doc(highestBidderId).get();
      const bidderData = bidderDoc.data();
      const bidderEmail = bidderData && bidderData.email ? bidderData.email : "unknown@example.com";
      const bidderName = bidderData && bidderData.name ? bidderData.name : "Bidder";

      // Build email messages.
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
        await transporter.sendMail(mailOptionsSeller);
        await transporter.sendMail(mailOptionsBidder);
        console.log(`Emails sent for listing ${listingId}`);
      } catch (error) {
        console.error(`Error sending emails for listing ${listingId}:`, error);
      }
    }
  });

  await Promise.all(promises);
  console.log("Bid finalization complete.");
});
