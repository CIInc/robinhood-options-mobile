// import * as functions from 'firebase-functions';
import * as https from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
// import * as plaid from 'plaid';

import {
  Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode,
} from "plaid";

admin.initializeApp();

// const sandboxConfiguration = new Configuration({
//   basePath: PlaidEnvironments.sandbox,
//   baseOptions: {
//     headers: {
//       "PLAID-CLIENT-ID": "65e4a9695df626001bc299fa",
//       "PLAID-SECRET": "72c0bc3265418b9c84dc754c7d61e2",
//     },
//   },
// });
const configuration = new Configuration({
  basePath: PlaidEnvironments.production,
  baseOptions: {
    headers: {
      "PLAID-CLIENT-ID": "65e4a9695df626001bc299fa",
      "PLAID-SECRET": "d27d4f612cf641411ed491c469a147",
    },
  },
});
// const redirectUrl = "https://realizealpha.web.app";

const plaidClient = new PlaidApi(configuration);

export const createPlaidLinkToken = https.onCall({}, async (request) => {
  // // Check if the user is authenticated
  // if (!request.auth) {
  //     throw new https.HttpsError(
  //         "unauthenticated", "User must be authenticated.");
  // }

  // const userId = request.auth.uid;
  console.log(request.auth);

  try {
    const createTokenResponse = await plaidClient.linkTokenCreate({
      user: {
        client_user_id: "1234567890", // userId,
      },
      client_name: "RealizeAlpha",
      // redirect_uri: redirectUrl,
      country_codes: [CountryCode.Us],
      language: "en",
      products: [Products.Investments, Products.Transactions],
    });

    return { link_token: createTokenResponse.data.link_token };
  } catch (error) {
    console.error("Error creating Plaid Link token:", error);
    throw new https.HttpsError(
      "internal", "Failed to create Plaid Link token.");
    return;
  }
});

export const exchangePublicTokenForAccessToken = https.onCall({},
  async (request) => {
    logger.info(request.data, { structuredData: true });
    const tokenExchangeResponse = await plaidClient.itemPublicTokenExchange({
      public_token: request.data["publicToken"],
    });
    return tokenExchangeResponse.data;
  });

export const getInvestmentsHoldings = https.onCall({},
  async (request) => {
    logger.info(request.data, { structuredData: true });
    const tokenExchangeResponse = await plaidClient.investmentsHoldingsGet({
      access_token: request.data["access_token"],
    });
    return tokenExchangeResponse.data;
  });

export const getInvestmentsTransactions = https.onCall({},
  async (request) => {
    logger.info(request.data, { structuredData: true });
    const tokenExchangeResponse = await plaidClient.investmentsTransactionsGet({
      access_token: request.data["access_token"],
      start_date: request.data["start_date"], // YYYY-MM-DD
      end_date: request.data["end_date"],
    });
    return tokenExchangeResponse.data;
  });
