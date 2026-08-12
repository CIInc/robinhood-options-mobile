import { describe, expect, test } from "@jest/globals";
import {
  containsNonFiniteNumber,
  sanitizeNonFiniteNumbers,
} from "../src/json-sanitizer";

describe("JSON number sanitization", () => {
  test("replaces nested non-finite numbers with null", () => {
    const assessment = {
      score: 65,
      indicators: {
        vix: { value: Number.NaN },
        tnx: { value: Number.POSITIVE_INFINITY },
      },
      history: [1, Number.NEGATIVE_INFINITY],
    };

    expect(containsNonFiniteNumber(assessment)).toBe(true);
    expect(sanitizeNonFiniteNumbers(assessment)).toEqual({
      score: 65,
      indicators: {
        vix: { value: null },
        tnx: { value: null },
      },
      history: [1, null],
    });
  });

  test("preserves class instances", () => {
    const timestamp = new Date();
    expect(sanitizeNonFiniteNumbers({ timestamp })).toEqual({ timestamp });
    expect(containsNonFiniteNumber({ timestamp })).toBe(false);
  });
});
