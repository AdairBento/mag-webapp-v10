import type { Request, Response, NextFunction } from "express";
import { z } from "zod";
const uuid = z.string().uuid();

declare global {
  namespace Express {
    interface Request {
      tenantId?: string;
    }
  }
}

export const tenantMiddleware = (req: Request, res: Response, next: NextFunction) => {
  if (req.path.startsWith("/auth") || req.path.startsWith("/webhooks")) return next();
  const tenantId = req.headers["x-tenant-id"] as string;
  if (!tenantId)
    return res
      .status(400)
      .json({ error: { code: "MISSING_TENANT", message: "Header x-tenant-id é obrigatório" } });
  try {
    uuid.parse(tenantId);
    req.tenantId = tenantId;
    next();
  } catch {
    return res
      .status(400)
      .json({ error: { code: "INVALID_TENANT", message: "x-tenant-id deve ser um UUID válido" } });
  }
};
