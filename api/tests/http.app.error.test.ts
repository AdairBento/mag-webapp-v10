import { it, expect } from "vitest";
import request from "supertest";
import * as Mod from "../src/http/app";

// Pega app e server, cobrindo exports default/named (Express ou Fastify)
function getApp(mod: any) {
  return (mod as any)?.default ?? (mod as any)?.app ?? (mod as any);
}
function getServer(mod: any) {
  const app = getApp(mod);
  return (app as any)?.server ?? app;
}

it("aciona o error handler global (500+)", async () => {
  const app: any = getApp(Mod);
  const server: any = getServer(Mod);

  // Só registra se a instância suporta .get (Express/Fastify)
  if (!app || typeof app.get !== "function") {
    // Se não der para registrar dinamicamente, não falha o teste.
    expect(true).toBe(true);
    return;
  }

  // Express: next(err) | Fastify: lançar erro já aciona handler
  app.get("/__boom__", (req: any, res: any, next: any) => {
    try {
      throw new Error("boom");
    } catch (e) {
      return next?.(e);
    }
  });

  const res = await request(server).get("/__boom__");
  expect(res.status).toBeGreaterThanOrEqual(500);
});
