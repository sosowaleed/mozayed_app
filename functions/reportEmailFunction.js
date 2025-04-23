
// Import Firebase Functions and Admin SDK
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin SDK
admin.initializeApp();

// HTTP-triggered function to send a report email
// This function expects a POST request with a JSON body containing:
// - recipient: The email address to send the report to
// - category: The category of the report
// - flag: A flag or status related to the report
// - bodyText: The content of the email
exports.sendReportEmailHTTP = onRequest(
  { secrets: ["EMAIL_USER", "EMAIL_PASS"] }, // Secrets for email authentication
  async (req, res) => {
    // Check if the request method is POST
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed. Please use POST.");
    }

    // Extract required fields from the request body
    const { recipient, category, flag, bodyText } = req.body;

    // Validate that all required fields are provided
    if (!recipient || !category || !flag || !bodyText) {
      return res
        .status(400)
        .json({ error: "Missing required fields: recipient, category, flag, or bodyText." });
    }

    // Configure the email transporter using Gmail and environment secrets
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAIL_USER, // Email username from secrets
        pass: process.env.EMAIL_PASS, // Email password from secrets
      },
    });

    // Define the email options
    const mailOptions = {
      from: process.env.EMAIL_USER, // Sender email address
      to: recipient, // Recipient email address
      subject: `${category} - ${flag}`, // Email subject
      text: bodyText, // Email body content
    };

    try {
      // Attempt to send the email
      await transporter.sendMail(mailOptions);
      console.log(`Email sent to ${recipient} with subject "${category} - ${flag}"`);
      res.json({ success: true }); // Respond with success
    } catch (error) {
      // Handle errors during email sending
      console.error("Error sending email:", error);
      res.status(500).json({ error: "Failed to send email", details: error.toString() });
    }
  }
);
