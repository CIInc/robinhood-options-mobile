import { HttpsError } from "firebase-functions/v2/https";

const mockSet = jest.fn();
const mockUpdate = jest.fn();
const mockDelete = jest.fn();
const mockDocGet = jest.fn();
const mockDocRef = {
  id: "alert-123",
  set: mockSet,
  update: mockUpdate,
  delete: mockDelete,
  get: mockDocGet,
};

const mockDoc = jest.fn().mockImplementation((docId?: string) => {
  if (docId) {
    return mockDocRef;
  }
  return mockDocRef;
});

const mockWhere = jest.fn();
const mockOrderBy = jest.fn();
const mockCollectionGet = jest.fn();

const mockCollection = jest.fn().mockReturnValue({
  doc: mockDoc,
  where: mockWhere.mockReturnValue({
    orderBy: mockOrderBy.mockReturnValue({
      get: mockCollectionGet,
    }),
  }),
});

jest.mock("firebase-admin", () => ({
  apps: [{}],
  initializeApp: jest.fn(),
  firestore: Object.assign(
    () => ({
      collection: mockCollection,
    }),
    {
      FieldValue: {
        serverTimestamp: () => "MOCK_TIMESTAMP",
      },
    }
  ),
}));

jest.mock("../src/options-flow-utils", () => ({
  fetchOptionsFlowForSymbols: jest.fn(),
}));

import {
  createOptionAlert,
  toggleOptionAlert,
  deleteOptionAlert,
} from "../src/options-flow";

describe("options-flow alert endpoints", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("createOptionAlert", () => {
    it("rejects unauthenticated requests", async () => {
      await expect(
        (createOptionAlert as any).run({
          data: { symbol: "AAPL" },
          auth: undefined,
        })
      ).rejects.toThrow(
        new HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        )
      );
    });

    it("rejects invalid symbols", async () => {
      const invalidSymbols = ["", "TOOLONGSYMBOL123", "AAPL$", "   "];
      for (const symbol of invalidSymbols) {
        await expect(
          (createOptionAlert as any).run({
            data: { symbol },
            auth: { uid: "user-123" },
          })
        ).rejects.toThrow(
          new HttpsError(
            "invalid-argument",
            "Symbol is required and must be a valid stock symbol " +
            "(1-10 characters)."
          )
        );
      }
    });

    it("rejects negative or non-finite values", async () => {
      await expect(
        (createOptionAlert as any).run({
          data: { symbol: "AAPL", minPremium: -500 },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "invalid-argument",
          "Min premium must be a positive finite number."
        )
      );

      await expect(
        (createOptionAlert as any).run({
          data: { symbol: "AAPL", targetPremium: Infinity },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "invalid-argument",
          "Target premium must be a positive finite number."
        )
      );

      await expect(
        (createOptionAlert as any).run({
          data: { symbol: "AAPL", minVolume: -10 },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "invalid-argument",
          "Min volume must be a positive finite number."
        )
      );
    });

    it("creates alert with valid data", async () => {
      mockSet.mockResolvedValueOnce(undefined);
      const res = await (createOptionAlert as any).run({
        data: {
          symbol: "aapl",
          minPremium: 100000,
          minVolume: 500,
        },
        auth: { uid: "user-123" },
      });

      expect(res).toEqual({ success: true, id: "alert-123" });
      expect(mockSet).toHaveBeenCalledWith(
        expect.objectContaining({
          uid: "user-123",
          symbol: "AAPL",
          minPremium: 100000,
          minVolume: 500,
          isActive: true,
        })
      );
    });
  });

  describe("toggleOptionAlert", () => {
    it("rejects unauthenticated requests", async () => {
      await expect(
        (toggleOptionAlert as any).run({
          data: { alertId: "alert-123", isActive: false },
          auth: undefined,
        })
      ).rejects.toThrow(
        new HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        )
      );
    });

    it("rejects invalid alertId", async () => {
      const invalidAlertIds = ["", null, undefined, 123, "   "];
      for (const alertId of invalidAlertIds) {
        await expect(
          (toggleOptionAlert as any).run({
            data: { alertId, isActive: false },
            auth: { uid: "user-123" },
          })
        ).rejects.toThrow(
          new HttpsError(
            "invalid-argument",
            "Alert ID is required and must be a valid string."
          )
        );
      }
    });

    it("rejects non-boolean isActive", async () => {
      await expect(
        (toggleOptionAlert as any).run({
          data: { alertId: "alert-123", isActive: "false" },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "invalid-argument",
          "isActive must be a boolean."
        )
      );
    });

    it("throws not-found when document does not exist", async () => {
      mockDocGet.mockResolvedValueOnce({ exists: false });

      await expect(
        (toggleOptionAlert as any).run({
          data: { alertId: "alert-123", isActive: false },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError("not-found", "Alert not found")
      );
    });

    it("throws permission-denied when caller is not owner", async () => {
      mockDocGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ uid: "other-user" }),
      });

      await expect(
        (toggleOptionAlert as any).run({
          data: { alertId: "alert-123", isActive: false },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "permission-denied",
          "Not authorized to update this alert"
        )
      );
    });
  });

  describe("deleteOptionAlert", () => {
    it("rejects unauthenticated requests", async () => {
      await expect(
        (deleteOptionAlert as any).run({
          data: { alertId: "alert-123" },
          auth: undefined,
        })
      ).rejects.toThrow(
        new HttpsError(
          "unauthenticated",
          "The function must be called while authenticated."
        )
      );
    });

    it("rejects invalid alertId", async () => {
      await expect(
        (deleteOptionAlert as any).run({
          data: { alertId: "" },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "invalid-argument",
          "Alert ID is required and must be a valid string."
        )
      );
    });

    it("throws permission-denied when caller does not own alert", async () => {
      mockDocGet.mockResolvedValueOnce({
        exists: true,
        data: () => ({ uid: "other-user" }),
      });

      await expect(
        (deleteOptionAlert as any).run({
          data: { alertId: "alert-123" },
          auth: { uid: "user-123" },
        })
      ).rejects.toThrow(
        new HttpsError(
          "permission-denied",
          "Not authorized to delete this alert"
        )
      );
    });
  });
});
