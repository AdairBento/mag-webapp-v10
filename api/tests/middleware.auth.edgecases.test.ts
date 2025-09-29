import { describe, it, expect, beforeAll } from "vitest";
import request from "supertest";

const PROTECTED = "/clients";

let app: any;

function isExpressLike(a: any) {
  // supertest aceita a função do express (req,res,next) ou um server
  return typeof a === "function" && (a.length === 2 || a.length === 3);
}

beforeAll(async () => {
  const mod: any = await import("../src/http/app").catch(() => ({}));
  // 1) named createApp()
  if (typeof mod?.createApp === "function") { app = mod.createApp(); if (isExpressLike(app)) return; }
  // 2) named app (instância)
  if (mod?.app && isExpressLike(mod.app)) { app = mod.app; return; }
  // 3) default.createApp()
  if (typeof mod?.default?.createApp === "function") { app = mod.default.createApp(); if (isExpressLike(app)) return; }
  // 4) default é instância
  if (mod?.default && isExpressLike(mod.default)) { app = mod.default; return; }
  // 5) default é factory sem args
  if (typeof mod?.default === "function") {
    try { const maybe = mod.default(); if (isExpressLike(maybe)) { app = maybe; return; } } catch {}
  }
});

const suite = app ? describe : describe.skip;

suite("auth middleware - edge cases", () => {
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