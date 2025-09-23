import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/server";

describe("app (HTTP smoke)", () => {
  it("returns 404 for unknown route", async () => {
    const res = await request(app).get("/__not_found__");
    expect(res.status).toBe(404);
  });
});
