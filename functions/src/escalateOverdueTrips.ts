import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import * as functions from "firebase-functions";
import { DateTime } from "luxon";
import { sendSms } from "./smsProvider";

const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFromNumber = defineSecret("TWILIO_FROM_NUMBER");

const TRIPS_COLLECTION = "trips";
const TIMEZONE = "Australia/Brisbane";
const CLAIM_LEASE_MS = 2 * 60 * 1000;

type TripDoc = {
  active?: boolean;
  etaUtc?: admin.firestore.Timestamp | null;
  acknowledgedAtUtc?: admin.firestore.Timestamp | null;
  endedAtUtc?: admin.firestore.Timestamp | null;
  primarySmsSentAtUtc?: admin.firestore.Timestamp | null;
  allSmsSentAtUtc?: admin.firestore.Timestamp | null;
  // Stage 1 (primary) tracking
  primarySmsClaimExpiresAtMs?: number | null;
  primarySmsToE164?: string | null;
  primarySmsSid?: string | null;

  // Stage 2 (all contacts) tracking
  allSmsClaimExpiresAtMs?: number | null;
  allSmsTargetPhones?: string[] | null;
  allSmsSidsByPhone?: Record<string, string> | null;
  emergencyContacts?: Array<{ name: string; phoneE164: string; isPrimary: boolean }>;
  lastLocation?: {
    lat?: number;
    lng?: number;
    timestamp?: admin.firestore.Timestamp;
    timestampUtc?: admin.firestore.Timestamp;
    accuracyM?: number;
  } | null;
  name?: string;
  rampName?: string;
  personsOnBoard?: number;
};

function etaLocal(etaUtc: admin.firestore.Timestamp): string {
  const dt = DateTime.fromJSDate(etaUtc.toDate(), { zone: "utc" }).setZone(TIMEZONE);
  return dt.toFormat("HH:mm dd LLL");
}

function lastSeenLocal(ts: admin.firestore.Timestamp | undefined): string {
  if (!ts) return "—";
  const dt = DateTime.fromJSDate(ts.toDate(), { zone: "utc" }).setZone(TIMEZONE);
  return dt.toFormat("HH:mm dd LLL");
}

function mapLink(lat: number | undefined, lng: number | undefined): string {
  if (lat == null || lng == null) return "";
  return `https://maps.google.com/?q=${lat},${lng}`;
}

function buildPrimarySms(d: TripDoc, etaLocalStr: string, lastSeenStr: string, link: string): string {
  const skipperName = (d.name ?? "the skipper").trim() || "the skipper";
  const rampName = (d.rampName ?? "(ramp not set)").trim() || "(ramp not set)";
  const pob = d.personsOnBoard != null ? String(d.personsOnBoard) : "(unknown)";
  const loc = d.lastLocation;
  const lat = loc?.lat;
  const lng = loc?.lng;
  const lastLine =
    lat != null && lng != null
      ? `Last known: ${lat},${lng} at ${lastSeenStr}\nMap: ${link}`
      : "Last known location unavailable.";
  return (
    `Marine Safe ALERT: No check-in from ${skipperName} for 30 min after ETA.\n` +
    `Trip: ${rampName} return by ${etaLocalStr}\n` +
    `People on board: ${pob}\n` +
    `${lastLine}\n` +
    `Please try calling them now. If concerned, contact Marine Rescue / 000.`
  );
}

function buildAllContactsSms(d: TripDoc, etaLocalStr: string, lastSeenStr: string, link: string): string {
  const skipperName = (d.name ?? "the skipper").trim() || "the skipper";
  const loc = d.lastLocation;
  const lat = loc?.lat;
  const lng = loc?.lng;
  const lastLine =
    lat != null && lng != null
      ? `Last known: ${lat},${lng} at ${lastSeenStr}\nMap: ${link}`
      : "Last known location unavailable.";
  return (
    `Marine Safe ALERT (Escalated): Still no reply from ${skipperName}.\n` +
    `ETA was ${etaLocalStr}. ${lastLine}\n` +
    `Please coordinate and consider contacting Marine Rescue / 000.`
  );
}

export const escalateOverdueTrips = onSchedule(
  {
    schedule: "* * * * *",
    timeoutSeconds: 120,
    memory: "256MiB",
    secrets: [twilioAccountSid, twilioAuthToken, twilioFromNumber],
  },
  async () => {
    const db = admin.firestore();
    const now = DateTime.utc();
    const thirtyMinutesAgo = now.minus({ minutes: 30 }).toJSDate();
    const fortyMinutesAgo = now.minus({ minutes: 40 }).toJSDate();
    const nowMs = Date.now();

    const snapshot = await db
      .collection(TRIPS_COLLECTION)
      .where("active", "==", true)
      .get();

    for (const doc of snapshot.docs) {
      const id = doc.id;
      const d = doc.data() as TripDoc;

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
      const etaLocalStr = etaLocal(d.etaUtc!);
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
          const data = fresh.data() as TripDoc | undefined;
          if (!data) return;
          if (data.primarySmsSentAtUtc != null) return;
          if (data.acknowledgedAtUtc != null || data.endedAtUtc != null) return;
          if (data.active !== true) return;
          const leaseExp = data.primarySmsClaimExpiresAtMs ?? 0;
          if (leaseExp > nowMs) return; // another runner owns lease
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
          const result = await sendSms(to, body);
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
          } else {
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
        let targetPhones: string[] = [];
        let sidsByPhone: Record<string, string> = {};
        await db.runTransaction(async (tx) => {
          const fresh = await tx.get(doc.ref);
          const freshData = fresh.data() as TripDoc | undefined;
          if (!freshData) return;
          if (freshData.allSmsSentAtUtc != null) return;
          if (freshData.acknowledgedAtUtc != null || freshData.endedAtUtc != null) return;
          if (freshData.active !== true) return;
          const leaseExp = freshData.allSmsClaimExpiresAtMs ?? 0;
          if (leaseExp > nowMs) return;

          const contacts = freshData.emergencyContacts ?? [];
          const phones = contacts
            .map((c) => (c.phoneE164 ?? "").trim())
            .filter((p) => p.length > 0);
          if (phones.length === 0) return;

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
            if (sidsByPhone[toRaw]) continue;
            const result = await sendSms(toRaw, bodyAll);
            if (result.ok) {
              sentThisRun++;
              await doc.ref.update({
                [`allSmsSidsByPhone.${toRaw}`]: result.sid,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAtMs: Date.now(),
              });
              sidsByPhone[toRaw] = result.sid;
              functions.logger.info("Escalation SMS sent", { tripId: id, stage: "all", to: result.toE164, sid: result.sid });
            } else {
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
          } else {
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
  }
);
