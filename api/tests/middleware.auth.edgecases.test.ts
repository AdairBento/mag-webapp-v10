import { describe, it, expect } from "vitest";
import express from "express";
import request from "supertest";
import auth from "../src/middleware/auth";

const app = express();
const PROTECTED = "/protected";

app.get(PROTECTED, auth, (_req, res) => res.sendStatus(200));

describe("auth middleware - edge cases", () => {
  it("401 quando NÃO há Authorization", async () => {
    const res = await request(app).get(PROTECTED);
    expect(res.status).toBe(401);
  });

  it("401 quando esquema NÃO é Bearer", async () => {
    const res = await request(app)
      .get(PROTECTED)
      .set("Authorization", "Basic Zm9vOmJhcg==");
    expect(res.status).toBe(401);
  });

  it("401 quando Bearer está sem token", async () => {
    const res = await request(app)
      .get(PROTECTED)
      .set("Authorization", "Bearer ");
    expect(res.status).toBe(401);
  });

  it("401 quando Bearer tem formato inválido (partes extras)", async () => {
    const res = await request(app)
      .get(PROTECTED)
      .set("Authorization", "Bearer a.b.c extra");
    expect(res.status).toBe(401);
  });
});
