import { describe, expect, test } from "@jest/globals";
import { redactSensitiveUrl } from "../src/utils";

describe("redactSensitiveUrl", () => {
  test("redacts credentials and preserves non-sensitive query values", () => {
    const result = redactSensitiveUrl(
      "https://api.example.com/data?symbol=HOLX&apikey=secret-value"
    );
    const parsed = new URL(result);

    expect(parsed.searchParams.get("symbol")).toBe("HOLX");
    expect(parsed.searchParams.get("apikey")).toBe("[REDACTED]");
    expect(result).not.toContain("secret-value");
  });

  test("redacts sensitive values in a malformed URL", () => {
    const result = redactSensitiveUrl("/data?token=secret-value&symbol=HOLX");

    expect(result).toBe("/data?token=[REDACTED]&symbol=HOLX");
  });
});
