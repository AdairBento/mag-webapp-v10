import type { Request, Response, NextFunction } from "express";

export interface AuthUser {
  id: string;
  email?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export default function auth(req: Request, res: Response, next: NextFunction) {
  const h = req.header("authorization");
  if (!h || !h.startsWith("Bearer ")) {
    return res.status(401).json({ error: "unauthorized" });
  }
  const token = h.slice(7).trim();
  if (!token) return res.status(401).json({ error: "unauthorized" });

  // aqui normalmente validaríamos o JWT e carregaríamos o usuário
  req.user = { id: "test-user" };
  next();
}
