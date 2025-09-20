
import { Router } from 'express';
import { prisma } from '../index';
import { z } from 'zod';

const router = Router();
const upsert = z.object({ contractId: z.string().uuid().optional(), assetId: z.string().uuid().optional(), clientId: z.string().uuid().optional(), type: z.enum(['fine','accident','theft','damage','other']), description: z.string().min(1), amount: z.number().optional(), status: z.enum(['open','settled','canceled']).optional() });

router.get('/', async (req, res, next) => { try { const { type, status } = req.query as any; const data = await prisma.incident.findMany({ where: { tenantId: req.tenantId!, type: type as any, status: status as any }, orderBy: { createdAt: 'desc' }}); res.json({ data }); } catch (e) { next(e); } });
router.post('/', async (req, res, next) => { try { const payload = upsert.parse(req.body); const item = await prisma.incident.create({ data: { ...payload, tenantId: req.tenantId! }}); res.status(201).json(item); } catch (e) { next(e); } });
router.patch('/:id', async (req, res, next) => { try { const payload = upsert.partial().parse(req.body); const updated = await prisma.incident.update({ where: { id: req.params.id }, data: payload }); res.json(updated); } catch (e) { next(e); } });

export { router as incidentsRoutes };
