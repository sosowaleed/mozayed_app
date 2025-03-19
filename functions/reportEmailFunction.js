const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// HTTP-triggered function that sends a report email.
// It expects a POST request with a JSON body containing:
//   recipient, category, flag, and bodyText.
exports.sendReportEmailHTTP = onRequest({ secrets: ["EMAIL_USER", "EMAIL_PASS"] }, async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed. Please use POST.");
  }

  const { recipient, category, flag, bodyText } = req.body;
  if (!recipient || !category || !flag || !bodyText) {
    return res.status(400).json({ error: "Missing required fields: recipient, category, flag, or bodyText." });
  }

  // Configure transporter using secrets.
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: recipient,
    subject: `${category} - ${flag}`,
    text: bodyText,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Email sent to ${recipient} with subject "${category} - ${flag}"`);
    res.json({ success: true });
  } catch (error) {
    console.error("Error sending email:", error);
    res.status(500).json({ error: "Failed to send email", details: error.toString() });
  }
});
