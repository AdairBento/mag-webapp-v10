import { describe, it, expect } from "vitest";
import app from "../src/http/app";
import request from "supertest";
describe("app (HTTP smoke)", () => {
  it("returns 404 for unknown route", async () => {
    const res = await request(app).get("/__not_found__");
    expect(res.status).toBe(404);
  });
});

