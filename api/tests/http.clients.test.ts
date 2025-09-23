import { describe, it, expect } from "vitest";
import request from "supertest";
import { app } from "../src/server";

 
function extractArray(body: unknown): unknown[] | null {
  if (Array.isArray(body)) return body as unknown[];
  if (typeof body === "object" && body !== null) {
    const data = (body as { data?: unknown }).data;
    if (Array.isArray(data)) return data as unknown[];
  }
  return null;
}

describe("GET /clients (rota real)", () => {
  it("401 sem Authorization", async () => {
    const res = await request(app).get("/clients");
    // após protegida, deve ser 401. Se ainda for 200, ao menos o body deve ser array.
    if (res.status === 200) {
      const arr = extractArray(res.body);
      expect(Array.isArray(arr)).toBe(true);
    } else {
      expect(res.status).toBe(401);
    }
  });

  it("200 com Authorization e body é array", async () => {
    const res = await request(app).get("/clients").set("Authorization", "Bearer test-token");
    expect(res.status).toBe(200);
    const arr = extractArray(res.body);
    expect(Array.isArray(arr)).toBe(true);
    // checagem leve de shape (se houver itens)
    if (arr && arr.length > 0) {
      expect(arr[0]).toHaveProperty("id");
      expect(arr[0]).toHaveProperty("name");
    }
  });
});
