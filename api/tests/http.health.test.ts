import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/server";

describe("GET /health", () => {
  it("responde 200 { ok: true }", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });
});
