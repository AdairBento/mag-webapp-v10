
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

declare global { namespace Express { interface Request { user?: { userId: string; email: string } } } }

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  if (req.path.startsWith('/auth') || req.path.startsWith('/webhooks')) return next();
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!token) return res.status(401).json({ error: { code: 'NO_TOKEN', message: 'Authorization Bearer token ausente' }});
  try { const p = jwt.verify(token, process.env.JWT_SECRET!) as any; req.user = { userId: p.userId, email: p.email }; next(); }
  catch { return res.status(401).json({ error: { code: 'INVALID_TOKEN', message: 'Token inválido ou expirado' }}); }
}
