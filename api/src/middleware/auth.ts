import type { Request, Response, NextFunction } from "express";

export type AuthUser = { id: string };

export function auth(req: Request, res: Response, next: NextFunction) {
  // Preflight CORS passa sem auth
  if (req.method === "OPTIONS") return next();

  const h = req.header("authorization") ?? req.header("Authorization");
  if (!h) return res.status(401).json({ error: "unauthorized" });

  const parts = h.trim().split(/\s+/);
  if (parts.length !== 2) {
    return res.status(401).json({ error: "invalid_format" });
  }

  const [scheme, token] = parts;
  if (!scheme || scheme.toLowerCase() !== "bearer") {
    return res.status(401).json({ error: "invalid_scheme" });
  }

  const trimmed = (token ?? "").trim();
  if (!trimmed) return res.status(401).json({ error: "empty_token" });

  // Stub p/ testes
  if (trimmed === "test-token") {
    (req as any).user = { id: "test-user" };
  }

  return next();
}

export default auth;