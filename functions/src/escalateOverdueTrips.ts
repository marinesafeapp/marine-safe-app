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

type TripDoc = {
  active?: boolean;
  etaUtc?: admin.firestore.Timestamp | null;
  acknowledgedAtUtc?: admin.firestore.Timestamp | null;
  endedAtUtc?: admin.firestore.Timestamp | null;
  primarySmsSentAtUtc?: admin.firestore.Timestamp | null;
  allSmsSentAtUtc?: admin.firestore.Timestamp | null;
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

      // ETA + 30: primary only (transaction to prevent duplicate send)
      if (eta <= thirtyMinutesAgo && d.primarySmsSentAtUtc == null) {
        if (!primary?.phoneE164) {
          functions.logger.warn("Trip has no primary contact for SMS", { tripId: id });
          continue;
        }
        let claimed = false;
        await db.runTransaction(async (tx) => {
          const fresh = await tx.get(doc.ref);
          const data = fresh.data() as TripDoc | undefined;
          if (data?.primarySmsSentAtUtc != null) return;
          if (data?.acknowledgedAtUtc != null || data?.endedAtUtc != null) return;
          if (data?.active !== true) return;
          tx.update(doc.ref, {
            primarySmsSentAtUtc: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAtMs: Date.now(),
          });
          claimed = true;
        });
        if (claimed) {
          const body = buildPrimarySms(d, etaLocalStr, lastSeenStr, link);
          const sid = await sendSms(primary.phoneE164, body);
          functions.logger.info("Primary SMS sent", { tripId: id, sid: sid ?? "failed" });
        }
      }

      // ETA + 40: all contacts (transaction to prevent duplicate send)
      if (eta <= fortyMinutesAgo) {
        let claimed = false;
        let allContacts: TripDoc["emergencyContacts"] = [];
        await db.runTransaction(async (tx) => {
          const fresh = await tx.get(doc.ref);
          const freshData = fresh.data() as TripDoc | undefined;
          if (freshData?.allSmsSentAtUtc != null) return;
          if (freshData?.acknowledgedAtUtc != null || freshData?.endedAtUtc != null) return;
          if (freshData?.active !== true) return;
          const contacts = freshData.emergencyContacts ?? [];
          if (contacts.length === 0) return;
          allContacts = contacts;
          tx.update(doc.ref, {
            allSmsSentAtUtc: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAtMs: Date.now(),
          });
          claimed = true;
        });
        if (claimed && allContacts.length > 0) {
          const bodyAll = buildAllContactsSms(d, etaLocalStr, lastSeenStr, link);
          let sent = 0;
          for (const c of allContacts) {
            if (!c.phoneE164) continue;
            const sid = await sendSms(c.phoneE164, bodyAll);
            if (sid) sent++;
          }
          functions.logger.info("All-contacts SMS sent", { tripId: id, count: sent });
        }
      }
    }
  }
);
