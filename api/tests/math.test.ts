import { describe, it, expect } from "vitest";
import { sum } from "../src/utils/math";

describe("math", () => {
  it("sum", () => {
    expect(sum(2, 3)).toBe(5);
  });
});
