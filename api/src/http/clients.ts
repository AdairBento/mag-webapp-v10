
import { Router } from 'express';
import { prisma } from '../index';
import { z } from 'zod';

const router = Router();
const createClientSchema = z.object({ name: z.string().min(1), phone: z.string().optional(), whatsappOptIn: z.boolean().default(false) });

router.get('/', async (req, res, next) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const pageSize = Math.min(parseInt(req.query.pageSize as string) || 20, 100);
    const skip = (page - 1) * pageSize;
    const [clients, total] = await Promise.all([
      prisma.client.findMany({ where: { tenantId: req.tenantId! }, skip, take: pageSize, orderBy: { createdAt: 'desc' } }),
      prisma.client.count({ where: { tenantId: req.tenantId! } })
    ]);
    res.json({ data: clients, pagination: { page, pageSize, total, pages: Math.ceil(total / pageSize) } });
  } catch (e) { next(e) }
});

router.post('/', async (req, res, next) => {
  try { const data = createClientSchema.parse(req.body); const c = await prisma.client.create({ data: { ...data, tenantId: req.tenantId! } }); res.status(201).json(c); } catch (e) { next(e) }
});

export { router as clientsRoutes };
