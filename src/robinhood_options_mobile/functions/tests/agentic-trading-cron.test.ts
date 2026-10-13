import { describe, expect, test, jest, beforeEach } from "@jest/globals";

const mockVerifyIdToken = jest.fn() as jest.Mock<any>;

jest.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    collection: jest.fn(() => ({
      listDocuments: jest.fn(async () => []),
    })),
  }),
}));

jest.mock("../src/agentic-trading", () => ({
  performTradeProposal: jest.fn(async () => ({ status: "success" })),
}));

import { agenticTradingCronInvoke } from "../src/agentic-trading-cron";

describe("agenticTradingCronInvoke security tests", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("rejects request missing Authorization header with 401", async () => {
    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: {},
    } as any;

    const mockRes = {
      status: jest.fn().mockImplementation((code: any) => {
        responseStatus = code;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((data: any) => {
        responseJsonData = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Authentication required",
    });
    expect(mockVerifyIdToken).not.toHaveBeenCalled();
  });

  test("rejects request with invalid Bearer token with 401", async () => {
    mockVerifyIdToken.mockRejectedValueOnce(new Error("Invalid token"));

    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: {
        authorization: "Bearer invalid_token",
      },
    } as any;

    const mockRes = {
      status: jest.fn().mockImplementation((code: any) => {
        responseStatus = code;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((data: any) => {
        responseJsonData = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Unauthorized",
    });
    expect(mockVerifyIdToken).toHaveBeenCalledWith("invalid_token");
  });

  test("allows request with valid Bearer token", async () => {
    mockVerifyIdToken.mockResolvedValueOnce({ uid: "user123" });

    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: {
        authorization: "Bearer valid_token",
      },
    } as any;

    const mockRes = {
      status: jest.fn().mockImplementation((code: any) => {
        responseStatus = code;
        return mockRes;
      }),
      json: jest.fn().mockImplementation((data: any) => {
        responseJsonData = data;
        return mockRes;
      }),
    } as any;

    await (agenticTradingCronInvoke as any)(mockReq, mockRes);

    expect(mockVerifyIdToken).toHaveBeenCalledWith("valid_token");
    expect(responseStatus).toBeNull(); // didn't error out with status(401)
    expect(responseJsonData).toMatchObject({
      processedCount: 0,
      errorCount: 0,
    });
  });
});
