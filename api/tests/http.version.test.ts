import { describe, it, expect } from 'vitest';
import app from "../src/http/app";
import request from "supertest";
describe("GET /version", () => {
  it("retorna 200 e o shape esperado", async () => {
    const res = await request(app)
      .get("/version")
      .set("Authorization", "Bearer test");

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      name: expect.any(String),
      version: expect.any(String),
      node: expect.any(String),
      env: expect.any(String),
    });
    expect(res.body).toHaveProperty("commit"); // pode ser null
  });
});


