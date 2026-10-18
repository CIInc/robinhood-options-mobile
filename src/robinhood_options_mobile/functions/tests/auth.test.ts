import { describe, expect, test, jest } from "@jest/globals";
import { HttpsError } from "firebase-functions/v2/https";

const mockSetCustomUserClaims = jest.fn(async () => undefined);
const mockGetUser = jest.fn(async (uid: string) => ({
  uid,
  displayName: "Test User",
  email: "test@example.com",
}));

jest.mock("firebase-admin/auth", () => ({
  getAuth: () => ({
    setCustomUserClaims: mockSetCustomUserClaims,
    getUser: mockGetUser,
  }),
}));

// Import function under test after mocks
import { changeUserRole } from "../src/auth";

describe("changeUserRole Security & Input Validation", () => {
  test("rejects unauthenticated request (null auth)", async () => {
    const unauthenticatedRequest = {
      auth: null,
      data: { uid: "targetUser", role: "admin" },
    };

    const callFn = () => (changeUserRole as any).run(unauthenticatedRequest);

    await expect(callFn()).rejects.toThrow(HttpsError);
    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects unauthenticated request (missing uid in auth)", async () => {
    const requestMissingUid = {
      auth: { token: {} },
      data: { uid: "targetUser", role: "admin" },
    };

    const callFn = () => (changeUserRole as any).run(requestMissingUid);

    await expect(callFn()).rejects.toMatchObject({
      code: "unauthenticated",
    });
  });

  test("rejects non-admin request", async () => {
    const nonAdminRequest = {
      auth: { uid: "callerUser", token: { role: "user" } },
      data: { uid: "targetUser", role: "admin" },
    };

    const callFn = () => (changeUserRole as any).run(nonAdminRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "permission-denied",
    });
  });

  test("rejects invalid arguments (non-string uid or role)", async () => {
    const invalidRequest = {
      auth: { uid: "adminUser", token: { role: "admin" } },
      data: { uid: 12345, role: "admin" }, // numeric uid
    };

    const callFn = () => (changeUserRole as any).run(invalidRequest);

    await expect(callFn()).rejects.toMatchObject({
      code: "invalid-argument",
    });
  });

  test("allows admin to successfully change user role", async () => {
    const validAdminRequest = {
      auth: { uid: "adminUser", token: { role: "admin" } },
      data: { uid: "targetUser", role: "editor" },
    };

    const result = await (changeUserRole as any).run(validAdminRequest);

    expect(mockSetCustomUserClaims).toHaveBeenCalledWith("targetUser", {
      role: "editor",
    });
    expect(mockGetUser).toHaveBeenCalledWith("targetUser");
    const expectedStr =
      "targetUser Test User <test@example.com> role: editor";
    expect(result).toBe(expectedStr);
  });
});
