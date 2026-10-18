import { describe, expect, test, jest } from "@jest/globals";

const mockGet = jest.fn().mockImplementation(() => {
  throw new Error("Internal Firestore error with sensitive stack trace");
});

const mockDoc = jest.fn().mockReturnValue({
  get: mockGet,
});

const mockVerifyIdToken = jest.fn() as jest.Mock<any>;

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: () => ({
    doc: mockDoc,
  }),
}));

jest.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    verifyIdToken: mockVerifyIdToken,
  }),
}));

import { signalDiagnostics } from "../src/signal-diagnostics";

describe("signalDiagnostics security tests", () => {
  test("rejects unauthenticated or non-admin requests with 401", async () => {
    let responseStatus: number | null = null;
    let responseJsonData: any = null;

    const mockReq = {
      headers: {},
      query: {},
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

    await (signalDiagnostics as any)(mockReq, mockRes);

    expect(responseStatus).toBe(401);
    expect(responseJsonData).toEqual({
      error: "Unauthorized: Admin privileges required.",
    });
  });

  test(
    "does not leak error details in 500 response for authenticated admin",
    async () => {
      mockVerifyIdToken.mockResolvedValueOnce({
        uid: "adminUser",
        role: "admin",
      });

      let responseStatus: number | null = null;
      let responseJsonData: any = null;

      const mockReq = {
        headers: {
          authorization: "Bearer valid-admin-token",
        },
        query: {
          symbol: "AAPL",
        },
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

      await (signalDiagnostics as any)(mockReq, mockRes);

      expect(responseStatus).toBe(500);
      expect(responseJsonData).toEqual({
        error: "Failed to run signal diagnostics",
      });
      expect(JSON.stringify(responseJsonData)).not.toContain(
        "Internal Firestore error"
      );
    }
  );
});
