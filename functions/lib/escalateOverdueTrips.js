"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.escalateOverdueTrips = void 0;
const admin = require("firebase-admin");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const params_1 = require("firebase-functions/params");
const functions = require("firebase-functions");
const luxon_1 = require("luxon");
const smsProvider_1 = require("./smsProvider");
const twilioAccountSid = (0, params_1.defineSecret)("TWILIO_ACCOUNT_SID");
const twilioAuthToken = (0, params_1.defineSecret)("TWILIO_AUTH_TOKEN");
const twilioFromNumber = (0, params_1.defineSecret)("TWILIO_FROM_NUMBER");
const TRIPS_COLLECTION = "trips";
const TIMEZONE = "Australia/Brisbane";
const CLAIM_LEASE_MS = 2 * 60 * 1000;
function etaLocal(etaUtc) {
    const dt = luxon_1.DateTime.fromJSDate(etaUtc.toDate(), { zone: "utc" }).setZone(TIMEZONE);
    return dt.toFormat("HH:mm dd LLL");
}
function lastSeenLocal(ts) {
    if (!ts)
        return "—";
    const dt = luxon_1.DateTime.fromJSDate(ts.toDate(), { zone: "utc" }).setZone(TIMEZONE);
    return dt.toFormat("HH:mm dd LLL");
}
function mapLink(lat, lng) {
    if (lat == null || lng == null)
        return "";
    return `https://maps.google.com/?q=${lat},${lng}`;
}
function buildPrimarySms(d, etaLocalStr, lastSeenStr, link) {
    const skipperName = (d.name ?? "the skipper").trim() || "the skipper";
    const rampName = (d.rampName ?? "(ramp not set)").trim() || "(ramp not set)";
    const pob = d.personsOnBoard != null ? String(d.personsOnBoard) : "(unknown)";
    const loc = d.lastLocation;
    const lat = loc?.lat;
    const lng = loc?.lng;
    const lastLine = lat != null && lng != null
        ? `Last known: ${lat},${lng} at ${lastSeenStr}\nMap: ${link}`
        : "Last known location unavailable.";
    return (`Marine Safe ALERT: No check-in from ${skipperName} for 30 min after ETA.\n` +
        `Trip: ${rampName} return by ${etaLocalStr}\n` +
        `People on board: ${pob}\n` +
        `${lastLine}\n` +
        `Please try calling them now. If concerned, contact Marine Rescue / 000.`);
}
function buildAllContactsSms(d, etaLocalStr, lastSeenStr, link) {
    const skipperName = (d.name ?? "the skipper").trim() || "the skipper";
    const loc = d.lastLocation;
    const lat = loc?.lat;
    const lng = loc?.lng;
    const lastLine = lat != null && lng != null
        ? `Last known: ${lat},${lng} at ${lastSeenStr}\nMap: ${link}`
        : "Last known location unavailable.";
    return (`Marine Safe ALERT (Escalated): Still no reply from ${skipperName}.\n` +
        `ETA was ${etaLocalStr}. ${lastLine}\n` +
        `Please coordinate and consider contacting Marine Rescue / 000.`);
}
exports.escalateOverdueTrips = (0, scheduler_1.onSchedule)({
    schedule: "* * * * *",
    timeoutSeconds: 120,
    memory: "256MiB",
    secrets: [twilioAccountSid, twilioAuthToken, twilioFromNumber],
}, async () => {
    const db = admin.firestore();
    const now = luxon_1.DateTime.utc();
    const thirtyMinutesAgo = now.minus({ minutes: 30 }).toJSDate();
    const fortyMinutesAgo = now.minus({ minutes: 40 }).toJSDate();
    const nowMs = Date.now();
    const snapshot = await db
        .collection(TRIPS_COLLECTION)
        .where("active", "==", true)
        .get();
    for (const doc of snapshot.docs) {
        const id = doc.id;
        const d = doc.data();
        if (d.acknowledgedAtUtc != null) {
            functions.logger.debug("Trip skipped (acknowledged)", { tripId: id });
            continue;
        }
        if (d.endedAtUtc != null) {
            functions.logger.debug("Trip skipped (ended)", { tripId: id });
            continue;
        }
        const eta = d.etaUtc?.toDate?.();
        if (!eta) {
            continue;
        }
        const contacts = d.emergencyContacts ?? [];
        const primary = contacts.find((c) => c.isPrimary) ?? contacts[0];
        const loc = d.lastLocation;
        const ts = loc?.timestampUtc ?? loc?.timestamp;
        const etaLocalStr = etaLocal(d.etaUtc);
        const lastSeenStr = lastSeenLocal(ts);
        const link = mapLink(loc?.lat, loc?.lng);
        // ETA + 30: primary only (lease + mark-sent-on-success)
        if (eta <= thirtyMinutesAgo && d.primarySmsSentAtUtc == null) {
            if (!primary?.phoneE164) {
                functions.logger.warn("Trip has no primary contact for SMS", { tripId: id });
                continue;
            }
            const to = primary.phoneE164;
            let claimed = false;
            await db.runTransaction(async (tx) => {
                const fresh = await tx.get(doc.ref);
                const data = fresh.data();
                if (!data)
                    return;
                if (data.primarySmsSentAtUtc != null)
                    return;
                if (data.acknowledgedAtUtc != null || data.endedAtUtc != null)
                    return;
                if (data.active !== true)
                    return;
                const leaseExp = data.primarySmsClaimExpiresAtMs ?? 0;
                if (leaseExp > nowMs)
                    return; // another runner owns lease
                tx.update(doc.ref, {
                    primarySmsClaimExpiresAtMs: nowMs + CLAIM_LEASE_MS,
                    primarySmsToE164: to,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAtMs: nowMs,
                });
                claimed = true;
            });
            if (claimed) {
                const body = buildPrimarySms(d, etaLocalStr, lastSeenStr, link);
                const result = await (0, smsProvider_1.sendSms)(to, body);
                if (result.ok) {
                    await doc.ref.update({
                        primarySmsSentAtUtc: admin.firestore.FieldValue.serverTimestamp(),
                        primarySmsSid: result.sid,
                        primarySmsToE164: result.toE164,
                        primarySmsClaimExpiresAtMs: null,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAtMs: Date.now(),
                    });
                    functions.logger.info("Primary SMS sent", { tripId: id, stage: "primary", to: result.toE164, sid: result.sid });
                }
                else {
                    await doc.ref.update({
                        primarySmsClaimExpiresAtMs: null,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAtMs: Date.now(),
                    });
                    functions.logger.error("Primary SMS send failed", { tripId: id, stage: "primary", to: result.toE164, error: result.error });
                }
            }
        }
        // ETA + 40: all contacts (lease + per-recipient dedupe + mark stage only after all success)
        if (eta <= fortyMinutesAgo) {
            let claimed = false;
            let targetPhones = [];
            let sidsByPhone = {};
            await db.runTransaction(async (tx) => {
                const fresh = await tx.get(doc.ref);
                const freshData = fresh.data();
                if (!freshData)
                    return;
                if (freshData.allSmsSentAtUtc != null)
                    return;
                if (freshData.acknowledgedAtUtc != null || freshData.endedAtUtc != null)
                    return;
                if (freshData.active !== true)
                    return;
                const leaseExp = freshData.allSmsClaimExpiresAtMs ?? 0;
                if (leaseExp > nowMs)
                    return;
                const contacts = freshData.emergencyContacts ?? [];
                const phones = contacts
                    .map((c) => (c.phoneE164 ?? "").trim())
                    .filter((p) => p.length > 0);
                if (phones.length === 0)
                    return;
                targetPhones = phones;
                sidsByPhone = freshData.allSmsSidsByPhone ?? {};
                tx.update(doc.ref, {
                    allSmsClaimExpiresAtMs: nowMs + CLAIM_LEASE_MS,
                    allSmsTargetPhones: phones,
                    allSmsSidsByPhone: sidsByPhone,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAtMs: nowMs,
                });
                claimed = true;
            });
            if (claimed && targetPhones.length > 0) {
                const bodyAll = buildAllContactsSms(d, etaLocalStr, lastSeenStr, link);
                let sentThisRun = 0;
                let failedThisRun = 0;
                for (const toRaw of targetPhones) {
                    if (sidsByPhone[toRaw])
                        continue;
                    const result = await (0, smsProvider_1.sendSms)(toRaw, bodyAll);
                    if (result.ok) {
                        sentThisRun++;
                        await doc.ref.update({
                            [`allSmsSidsByPhone.${toRaw}`]: result.sid,
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            updatedAtMs: Date.now(),
                        });
                        sidsByPhone[toRaw] = result.sid;
                        functions.logger.info("Escalation SMS sent", { tripId: id, stage: "all", to: result.toE164, sid: result.sid });
                    }
                    else {
                        failedThisRun++;
                        functions.logger.error("Escalation SMS failed", { tripId: id, stage: "all", to: result.toE164, error: result.error });
                    }
                }
                const allSucceeded = targetPhones.every((p) => Boolean(sidsByPhone[p]));
                if (allSucceeded) {
                    await doc.ref.update({
                        allSmsSentAtUtc: admin.firestore.FieldValue.serverTimestamp(),
                        allSmsClaimExpiresAtMs: null,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAtMs: Date.now(),
                    });
                    functions.logger.info("All-contacts SMS stage complete", { tripId: id, targetCount: targetPhones.length, sentThisRun, failedThisRun });
                }
                else {
                    await doc.ref.update({
                        allSmsClaimExpiresAtMs: null,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAtMs: Date.now(),
                    });
                    functions.logger.warn("All-contacts SMS stage incomplete (will retry)", { tripId: id, targetCount: targetPhones.length, sentThisRun, failedThisRun });
                }
            }
        }
    }
});
//# sourceMappingURL=escalateOverdueTrips.js.map