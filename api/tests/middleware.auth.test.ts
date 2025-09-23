import express from "express";
import request from "supertest";
import { describe, it, expect } from "vitest";
import auth from "../src/middleware/auth";

function makeApp() {
  const app = express();
  app.get("/protected", auth, (req, res) => {
    return res.json({ user: req.user?.id ?? null });
  });
  return app;
}

describe("middleware: auth", () => {
  it("retorna 401 sem Authorization", async () => {
    const app = makeApp();
    const res = await request(app).get("/protected");
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: "unauthorized" });
  });

  it("retorna 200 com Bearer token", async () => {
    const app = makeApp();
    const res = await request(app).get("/protected").set("Authorization", "Bearer test-token");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ user: "test-user" });
  });
});
