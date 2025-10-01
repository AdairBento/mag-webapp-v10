import type { Request, Response, NextFunction } from "express";

export type AuthUser = { id: string };

export function auth(req: Request, res: Response, next: NextFunction) {
  // Preflight CORS passa sem auth
  if (req.method === "OPTIONS") return next();

  const raw = String(req.headers["authorization"] ?? "");
  if (!raw) return res.status(401).json({ error: "unauthorized" });

  const m = raw.match(/^Bearer\s+(\S+)$/i);
  if (!m) return res.status(401).json({ error: "invalid Authorization format" });

  const token = m[1].trim();
  if (!token) return res.status(401).json({ error: "empty_token" });

  // Stub para testes
  if (token === "test-token") {
    (req as any).user = { id: "test-user" };
  }

  return next();
}

export default auth;
