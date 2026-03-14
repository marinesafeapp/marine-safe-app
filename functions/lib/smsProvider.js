"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendSms = sendSms;
const functions = require("firebase-functions");
const twilio = require("twilio");
/**
 * Send SMS via Twilio. Uses Firebase Functions secrets.
 * @param toE164 - Recipient in E.164 (e.g. +614xxxxxxxx)
 * @param body - Message body
 * @returns ok:true with SID on success, ok:false with error on failure
 */
async function sendSms(toE164, body) {
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    const fromNumber = process.env.TWILIO_FROM_NUMBER;
    if (!accountSid || !authToken || !fromNumber) {
        functions.logger.warn("Twilio not configured: missing TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, or TWILIO_FROM_NUMBER");
        return { ok: false, toE164, error: new Error("Twilio not configured") };
    }
    const normalized = toE164.startsWith("+") ? toE164 : `+${toE164}`;
    if (normalized.length < 10) {
        functions.logger.warn("Invalid E.164 for SMS:", normalized);
        return { ok: false, toE164: normalized, error: new Error("Invalid E.164") };
    }
    try {
        const client = twilio(accountSid, authToken);
        const message = await client.messages.create({
            body,
            from: fromNumber,
            to: normalized,
        });
        const sid = message.sid;
        if (!sid) {
            return { ok: false, toE164: normalized, error: new Error("Twilio returned no SID") };
        }
        return { ok: true, toE164: normalized, sid };
    }
    catch (e) {
        // Caller logs tripId + stage; keep provider log minimal.
        return { ok: false, toE164: normalized, error: e };
    }
}
//# sourceMappingURL=smsProvider.js.map