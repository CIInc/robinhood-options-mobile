/**
 * Recursively replaces non-finite numbers with null in JSON-like data.
 * Class instances such as Firestore timestamps are preserved.
 * @param {unknown} value Value to sanitize.
 * @return {unknown} JSON-safe value.
 */
export function sanitizeNonFiniteNumbers(value: unknown): unknown {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  if (Array.isArray(value)) {
    return value.map(sanitizeNonFiniteNumbers);
  }
  if (isPlainObject(value)) {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [
      key,
      sanitizeNonFiniteNumbers(entry),
    ]));
  }
  return value;
}

/**
 * Detects non-finite numbers in JSON-like data.
 * @param {unknown} value Value to inspect.
 * @return {boolean} Whether the value contains NaN or infinity.
 */
export function containsNonFiniteNumber(value: unknown): boolean {
  if (typeof value === "number") return !Number.isFinite(value);
  if (Array.isArray(value)) return value.some(containsNonFiniteNumber);
  if (isPlainObject(value)) {
    return Object.values(value).some(containsNonFiniteNumber);
  }
  return false;
}

/**
 * Checks whether a value is a plain object suitable for JSON recursion.
 * @param {unknown} value Value to inspect.
 * @return {boolean} Whether the value is a plain object.
 */
function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
