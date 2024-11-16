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
import * as plaidFunctions from "./plaid";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

export const createPlaidLinkToken = plaidFunctions.createPlaidLinkToken;
export const exchangePublicTokenForAccessToken =
  plaidFunctions.exchangePublicTokenForAccessToken;
export const getInvestmentsHoldings =
  plaidFunctions.getInvestmentsHoldings;
export const getInvestmentsTransactions =
  plaidFunctions.getInvestmentsTransactions;
