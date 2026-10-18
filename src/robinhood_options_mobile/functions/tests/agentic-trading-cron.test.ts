import { describe, expect, test, jest } from "@jest/globals";

const mockVerifyIdToken = jest.fn() as jest.Mock<any>;

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: jest.fn().mockReturnValue({
      listDocuments: jest.fn<any>().mockResolvedValue([]),
    }),
  }),
}));

jest.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

jest.mock("../src/agentic-trading", () => ({
  performTradeProposal: jest.fn(),
}));

import { agenticTradingCronInvoke } from "../src/agentic-trading-cron";

describe("agenticTradingCronInvoke security tests", () => {
  test("rejects unauthenticated request with 401", async () => {
    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = { headers: {} } as any;
    const mockRes = {
      status: jest.fn().mockImplementation((...args: any[]) => {
        responseStatus = args[0] as number;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((...args: any[]) => {
        responseJsonData = args[0];
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Unauthorized: Admin privileges required.",
    });
  });

  test("rejects non-admin authenticated request with 401", async () => {
    mockVerifyIdToken.mockResolvedValueOnce({
      uid: "user123",
      role: "user",
    });

    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: { authorization: "Bearer user-token" },
    } as any;
    const mockRes = {
      status: jest.fn().mockImplementation((...args: any[]) => {
        responseStatus = args[0] as number;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((...args: any[]) => {
        responseJsonData = args[0];
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Unauthorized: Admin privileges required.",
    });
  });

  test("allows admin request and executes cron", async () => {
    mockVerifyIdToken.mockResolvedValueOnce({
      uid: "admin123",
      role: "admin",
    });

    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: { authorization: "Bearer admin-token" },
    } as any;
    const mockRes = {
      status: jest.fn().mockImplementation((...args: any[]) => {
        responseStatus = args[0] as number;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((...args: any[]) => {
        responseJsonData = args[0];
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(responseStatus).toBeNull();
    expect(responseJsonData).toMatchObject({
      processedCount: 0,
      errorCount: 0,
    });
  });
});
