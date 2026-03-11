import * as admin from "firebase-admin";
import { escalateOverdueTrips } from "./escalateOverdueTrips";

admin.initializeApp();

export { escalateOverdueTrips };
