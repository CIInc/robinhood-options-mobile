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
import * as gemini from "./gemini";
import * as agenticTradingfunc from "./agentic-trading";
import * as agenticTradingCron from "./agentic-trading-cron";
import * as agenticTradingIntradayCron from "./agentic-trading-intraday-cron";
import * as riskguardAgent from "./riskguard-agent";
import * as copyTrading from "./copy-trading";
import * as tradeSignalNotifications from "./trade-signal-notifications";
import * as agenticTradingNotifications from "./agentic-trading-notifications";
import * as cronDiagnosticsFuncs from "./cron-diagnostics";
import * as signalDiagnosticsFuncs from "./signal-diagnostics";
import * as backtesting from "./backtesting";
import * as optionsFlow from "./options-flow";
import * as optionsFlowCron from "./options-flow-cron";
// import * as alphaagent from "./alphaagent";

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
// export const generateContent = gemini.generateContent;
// export const generateContent2 = gemini.generateContent2;
export const generateContent25 = gemini.generateContent25;
export const initiateTradeProposal =
  agenticTradingfunc.initiateTradeProposal;
export const getAgenticTradingConfig =
  agenticTradingfunc.getAgenticTradingConfig;
export const setAgenticTradingConfig =
  agenticTradingfunc.setAgenticTradingConfig;
export const agenticTradingCronJob = agenticTradingCron.agenticTradingCron;
export const agenticTradingCronInvoke =
  agenticTradingCron.agenticTradingCronInvoke;
export const agenticTradingIntradayCronJob =
  agenticTradingIntradayCron.agenticTradingIntradayCron;
export const agenticTrading15mCronJob =
  agenticTradingIntradayCron.agenticTrading15mCron;
// export const alphaagentTask = alphaagent.alphaagentTask;
export const riskguardTask = riskguardAgent.riskguardTask;
export const calculatePositionSize = riskguardAgent.calculatePositionSize;
export const onInstrumentOrderCreated = copyTrading.onInstrumentOrderCreated;
export const onOptionOrderCreated = copyTrading.onOptionOrderCreated;
export const onTradeSignalCreated =
  tradeSignalNotifications.onTradeSignalCreated;
export const onTradeSignalUpdated =
  tradeSignalNotifications.onTradeSignalUpdated;
export const sendAgenticTradeNotification =
  agenticTradingNotifications.sendAgenticTradeNotification;
export const cronDiagnostics = cronDiagnosticsFuncs.cronDiagnostics;
export const signalDiagnostics = signalDiagnosticsFuncs.signalDiagnostics;
export const runBacktest = backtesting.runBacktest;
export const getOptionsFlow = optionsFlow.getOptionsFlow;
export const createOptionAlert = optionsFlow.createOptionAlert;
export const getOptionAlerts = optionsFlow.getOptionAlerts;
export const deleteOptionAlert = optionsFlow.deleteOptionAlert;
export const toggleOptionAlert = optionsFlow.toggleOptionAlert;
export const optionsFlowCronJob = optionsFlowCron.optionsFlowCron;
