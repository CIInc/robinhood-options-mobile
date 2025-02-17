/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// import {onRequest} from "firebase-functions/v2/https";
// import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";

initializeApp();

import * as plaidfunc from "./plaid";
import * as authfunc from "./auth";
import * as messagingfunc from "./messaging";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

export const createPlaidLinkToken = plaidfunc.createPlaidLinkToken;
export const exchangePublicTokenForAccessToken =
  plaidfunc.exchangePublicTokenForAccessToken;
export const getInvestmentsHoldings =
  plaidfunc.getInvestmentsHoldings;
export const getInvestmentsTransactions =
  plaidfunc.getInvestmentsTransactions;
export const changeUserRole = authfunc.changeUserRole;
export const sendEachForMulticast = messagingfunc.sendEachForMulticast;
