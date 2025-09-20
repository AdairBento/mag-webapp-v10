
import { Router } from 'express';
import { prisma } from '../index';
import { z } from 'zod';
import dayjs from 'dayjs';

const router = Router();
const createPolicySchema = z.object({ insurerId: z.string().uuid(), assetId: z.string().uuid().optional(), contractId: z.string().uuid().optional(), policyNumber: z.string().min(1), startAt: z.string().transform(v => new Date(v)), endAt: z.string().transform(v => new Date(v)), periodicity: z.enum(['monthly','quarterly','yearly','single']).default('yearly'), premiumTotal: z.number().optional(), deductible: z.number().optional(), coverageJson: z.record(z.any()).optional(), notes: z.string().optional() });

router.get('/', async (req, res, next) => {
  try {
    const { assetId, contractId, status, insurerId } = req.query as any;
    const data = await prisma.insurancePolicy.findMany({ where: { tenantId: req.tenantId!, assetId, contractId, status: status as any, insurerId }, include: { insurer: true, premiums: true }, orderBy: { endAt: 'asc' } });
    res.json({ data });
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try { const data = createPolicySchema.parse(req.body); const item = await prisma.insurancePolicy.create({ data: { ...data, tenantId: req.tenantId! } }); res.status(201).json(item); } catch (e) { next(e); }
});

router.post('/:id/premiums/generate', async (req, res, next) => {
  try {
    const schema = z.object({ count: z.number().int().positive().default(12), startDue: z.string().optional() });
    const { count, startDue } = schema.parse(req.body);
    const policy = await prisma.insurancePolicy.findFirst({ where: { id: req.params.id, tenantId: req.tenantId! }});
    if (!policy) return res.status(404).json({ error: { code:'POLICY_NOT_FOUND', message:'Apólice não encontrada' }});
    const amount = (policy.premiumTotal ?? 0) / count; const base = startDue ? dayjs(startDue) : dayjs(policy.startAt);
    const premiums = Array.from({ length: count }).map((_, i) => ({ tenantId: policy.tenantId, policyId: policy.id, dueDate: base.add(i, 'month').toDate(), amount }));
    const created = await prisma.policyPremium.createMany({ data: premiums });
    res.status(201).json({ created: created.count });
  } catch (e) { next(e); }
});

router.get('/:id/premiums', async (req, res, next) => { try { const data = await prisma.policyPremium.findMany({ where: { tenantId: req.tenantId!, policyId: req.params.id }, orderBy: { dueDate: 'asc' }}); res.json({ data }); } catch (e) { next(e); } });

export { router as insurancePoliciesRoutes };
