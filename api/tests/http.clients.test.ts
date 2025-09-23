import { describe, it, expect, vi, afterEach } from "vitest";
import request from "supertest";
import { app } from "../src/server";
import * as ClientsSvc from "../src/services/clients";

afterEach(() => vi.restoreAllMocks());

describe("GET /clients", () => {
  it("retorna 401 sem Authorization", async () => {
    const res = await request(app).get("/clients");
    expect(res.status).toBe(401);
    expect(res.body).toEqual({ error: "unauthorized" });
  });

  it("retorna 200 com lista (mockada) quando autorizado", async () => {
    vi.spyOn(ClientsSvc, "listClients").mockResolvedValue([
      { id: "42", name: "Umbrella Inc." },
      { id: "7", name: "Wayne Enterprises" },
    ]);

    const res = await request(app).get("/clients").set("Authorization", "Bearer test-token");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      data: [
        { id: "42", name: "Umbrella Inc." },
        { id: "7", name: "Wayne Enterprises" },
      ],
    });
  });
});
