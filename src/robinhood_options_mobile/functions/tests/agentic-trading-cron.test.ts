import { describe, expect, test, jest } from "@jest/globals";
import { initializeApp } from "firebase-admin/app";

try {
  initializeApp();
} catch (e) {
  // Ignore error if app is already initialized
  void e;
}

const mockVerifyIdToken = jest.fn() as jest.Mock<any>;

jest.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({
    sendEachForMulticast: jest.fn(async () => ({})),
  }),
}));

const mockListDocuments = jest.fn().mockImplementation(async () => []) as
  jest.Mock<any>;

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: () => ({
      listDocuments: mockListDocuments,
    }),
  }),
}));

import { agenticTradingCronInvoke } from "../src/agentic-trading-cron";

describe("agenticTradingCronInvoke security tests", () => {
  test("returns 401 when Authorization header is missing", async () => {
    let statusCode = 0;
    let jsonBody: any = null;

    const mockReq = {
      headers: {},
    } as any;

    const mockRes = {
      status: jest.fn((code: number) => {
        statusCode = code;
        return mockRes;
      }),
      json: jest.fn((data: any) => {
        jsonBody = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(statusCode).toBe(401);
    expect(jsonBody).toEqual({ error: "Authentication required." });
  });

  test("returns 401 when Bearer token is invalid", async () => {
    mockVerifyIdToken.mockRejectedValueOnce(new Error("Token expired"));

    let statusCode = 0;
    let jsonBody: any = null;

    const mockReq = {
      headers: {
        authorization: "Bearer invalid_token",
      },
    } as any;

    const mockRes = {
      status: jest.fn((code: number) => {
        statusCode = code;
        return mockRes;
      }),
      json: jest.fn((data: any) => {
        jsonBody = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(statusCode).toBe(401);
    expect(jsonBody).toEqual({ error: "Invalid authentication token." });
  });

  test("returns 403 when user is authenticated but not an admin", async () => {
    mockVerifyIdToken.mockResolvedValueOnce({
      uid: "user123",
      role: "user",
    });

    let statusCode = 0;
    let jsonBody: any = null;

    const mockReq = {
      headers: {
        authorization: "Bearer user_token",
      },
    } as any;

    const mockRes = {
      status: jest.fn((code: number) => {
        statusCode = code;
        return mockRes;
      }),
      json: jest.fn((data: any) => {
        jsonBody = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(statusCode).toBe(403);
    expect(jsonBody).toEqual({ error: "Admin permissions required." });
  });

  test("allows admin users to trigger cron and returns result", async () => {
    mockVerifyIdToken.mockResolvedValueOnce({
      uid: "admin123",
      role: "admin",
    });

    let jsonBody: any = null;

    const mockReq = {
      headers: {
        authorization: "Bearer admin_token",
      },
    } as any;

    const mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn((data: any) => {
        jsonBody = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(jsonBody).toBeDefined();
    expect(jsonBody.processedCount).toBe(0);
    expect(jsonBody.errorCount).toBe(0);
  });
});
