import { describe, test, expect } from "@jest/globals";
import { formatAgenticProposalRejection } from
  "../src/agentic-proposal-message";

describe("formatAgenticProposalRejection", () => {
  test("reports only the Agentic reason when HOLD caused the rejection", () => {
    const message = formatAgenticProposalRejection(
      "Quantitative GEX data is N/A. Data insufficient for trade execution.",
      true,
      "Risk checks passed"
    );

    expect(message).toBe(
      "Agentic: Quantitative GEX data is N/A. " +
      "Data insufficient for trade execution."
    );
    expect(message).not.toContain("RiskGuard");
    expect(message).not.toContain("..");
  });

  test("reports the RiskGuard reason when it caused the rejection", () => {
    expect(formatAgenticProposalRejection(
      "BUY signal",
      false,
      "Sector exposure exceeds limit."
    )).toBe("RiskGuard: Sector exposure exceeds limit.");
  });
});
