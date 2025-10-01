import { describe, it, expect, vi } from "vitest";
import * as AuthMod from "../src/middleware/auth";

const authMw: any = (AuthMod as any).default ?? (AuthMod as any).auth ?? AuthMod;

describe("auth middleware - token presente (sem validação)", () => {
  it("chama next() quando existe Authorization Bearer, mesmo que inválido", async () => {
    const req: any = {
      headers: { authorization: "Bearer invalido.token.aqui" },
      header(name: string) {
        const h = this.headers || {};
        const key = String(name).toLowerCase();
        return h[name] ?? h[key] ?? h[String(name).toUpperCase()];
      },
      get(name: string) {
        return this.header(name);
      },
    };
    const res: any = {
      statusCode: 200,
      body: undefined as any,
      status(n: number) {
        this.statusCode = n;
        return this;
      },
      json(p: any) {
        this.body = p;
        return this;
      },
    };
    const next = vi.fn();

    await authMw(req, res, next);

    // comportamento atual: segue adiante
    expect(next).toHaveBeenCalled();
    expect(res.statusCode).toBe(200);
  });
});
