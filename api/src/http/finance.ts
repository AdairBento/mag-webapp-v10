
import { Router } from 'express';
import { prisma } from '../index';
import { z } from 'zod';

const router = Router();

router.get('/entries', async (req, res, next) => {
  try {
    const { status, type, from, to } = req.query as any;
    const data = await prisma.financeEntry.findMany({ where: { tenantId: req.tenantId!, status: status as any, type: type as any, dueDate: { gte: from ? new Date(from) : undefined, lte: to ? new Date(to) : undefined } }, orderBy: { dueDate: 'asc' } });
    res.json({ data });
  } catch (e) { next(e); }
});

router.post('/entries/:id/payments', async (req, res, next) => {
  try {
    const schema = z.object({ method: z.enum(['pix','cash','card','transfer','other']), amount: z.number().positive(), txId: z.string().optional() });
    const payload = schema.parse(req.body);
    const entry = await prisma.financeEntry.update({ where: { id: req.params.id }, data: { status: 'paid', amountPaid: payload.amount, paidAt: new Date(), description: payload.txId ? `PIX tx: ${payload.txId}` : undefined } });
    res.json(entry);
  } catch (e) { next(e); }
});

export { router as financeRoutes };
