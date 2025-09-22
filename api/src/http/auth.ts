import jwt, { Secret, JwtPayload, SignOptions } from "jsonwebtoken";
import { Router } from "express";

type JwtClaims = {
  sub: string;
  tenantId: string;
  roles?: string[];
} & Record<string, unknown>;

const rawSecret = process.env.JWT_SECRET ?? "";
if (!rawSecret) throw new Error("JWT_SECRET is not set");
const JWT_SECRET: Secret = rawSecret as Secret;

export function signToken(
  payload: JwtClaims,
  ttl: SignOptions["expiresIn"] = "1h"
) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: ttl });
}

export function verifyToken<T extends object = JwtPayload>(token: string): T {
  return jwt.verify(token, JWT_SECRET) as unknown as T;
}

// Router simples para emitir token
const r = Router();
r.post("/token", (req, res) => {
  const { sub, tenantId, roles, ttl } = req.body ?? {};
  if (!sub || !tenantId) return res.status(400).json({ error: "sub e tenantId são obrigatórios" });
  const token = signToken(
    { sub, tenantId, roles },
    (ttl ?? "1h") as SignOptions["expiresIn"]
  );
  res.json({ token });
});

export const authRoutes = r;
export default r;
