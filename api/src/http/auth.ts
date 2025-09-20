
import { Router } from 'express';
import { prisma } from '../index';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const router = Router();
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = loginSchema.parse(req.body);
    const user = await prisma.user.findUnique({ where: { email }, include: { tenants: true } });
    if (!user || !await bcrypt.compare(password, user.password)) return res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Email ou senha inválidos' }});
    const token = jwt.sign({ userId: user.id, email: user.email }, process.env.JWT_SECRET!, { expiresIn: process.env.JWT_EXPIRES_IN || '24h' });
    res.json({ token, user: { id: user.id, email: user.email, name: user.name } });
  } catch (e) { next(e) }
});

// Bootstrap sem seed: cria Tenant + Admin apenas se não há usuários
router.post('/register-first-admin', async (req, res, next) => {
  try {
    if (process.env.ALLOW_FIRST_ADMIN !== 'true') return res.status(403).json({ error: { code: 'DISABLED', message: 'Registro inicial desabilitado' }});
    const exists = await prisma.user.count();
    if (exists > 0) return res.status(409).json({ error: { code: 'ALREADY_INITIALIZED', message: 'Sistema já inicializado' }});

    const schema = z.object({ tenantName: z.string().min(1), email: z.string().email(), name: z.string().min(1), password: z.string().min(6) });
    const { tenantName, email, name, password } = schema.parse(req.body);

    const tenant = await prisma.tenant.create({ data: { name: tenantName } });
    const hashed = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({ data: { email, name, password: hashed } });
    await prisma.userTenant.create({ data: { userId: user.id, tenantId: tenant.id, role: 'admin' } });

    res.status(201).json({ message: 'Primeiro admin criado', tenantId: tenant.id, userId: user.id });
  } catch (e) { next(e); }
});

export { router as authRoutes };
