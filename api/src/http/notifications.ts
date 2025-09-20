
import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../index';
import { render, queueAndSendWhatsApp } from '../services/notificationService';

const router = Router();

router.get('/templates', async (req, res, next) => {
  try {
    const { kind, active } = req.query as any;
    const data = await prisma.notificationTemplate.findMany({ where: { tenantId: req.tenantId!, kind: kind as any, isActive: active !== undefined ? active === 'true' : undefined }, orderBy: { createdAt: 'desc' } });
    res.json({ data });
  } catch (e) { next(e); }
});

router.post('/templates', async (req, res, next) => {
  try {
    const schema = z.object({ name: z.string().min(1), kind: z.enum(['payment_overdue','contract_created','contract_due_today','custom','insurance_renewal','claim_status_changed']), channel: z.enum(['whatsapp','email','sms']).default('whatsapp'), content: z.string().min(1) });
    const data = schema.parse(req.body);
    const tpl = await prisma.notificationTemplate.create({ data: { ...data, tenantId: req.tenantId! } });
    res.status(201).json(tpl);
  } catch (e) { next(e); }
});

router.post('/preview', async (req, res, next) => {
  try {
    const schema = z.object({ templateId: z.string().uuid().optional(), content: z.string().optional(), variables: z.record(z.any()).default({}) });
    const { templateId, content, variables } = schema.parse(req.body);
    let base = content;
    if (templateId) {
      const tpl = await prisma.notificationTemplate.findFirst({ where: { id: templateId, tenantId: req.tenantId! } });
      if (!tpl) return res.status(404).json({ error: { code:'TEMPLATE_NOT_FOUND', message:'Template não encontrado' }});
      base = tpl.content;
    }
    if (!base) return res.status(400).json({ error: { code:'CONTENT_REQUIRED', message:'Informe templateId ou content' }});
    res.json({ rendered: render(base, variables) });
  } catch (e) { next(e); }
});

router.post('/send', async (req, res, next) => {
  try {
    const schema = z.object({ clientId: z.string().uuid().optional(), contractId: z.string().uuid().optional(), to: z.string().min(10), channel: z.literal('whatsapp'), templateId: z.string().uuid().optional(), content: z.string().min(1).optional(), variables: z.record(z.any()).default({}) });
    const data = schema.parse(req.body);
    let final = data.content; let tplId: string | undefined = data.templateId;
    if (data.templateId) {
      const tpl = await prisma.notificationTemplate.findFirst({ where: { id: data.templateId, tenantId: req.tenantId! } });
      if (!tpl) return res.status(404).json({ error: { code:'TEMPLATE_NOT_FOUND', message:'Template não encontrado' }});
      final = render(tpl.content, data.variables || {});
    }
    if (!final) return res.status(400).json({ error: { code:'CONTENT_REQUIRED', message:'Conteúdo final ausente' }});
    await queueAndSendWhatsApp({ tenantId: req.tenantId!, clientId: data.clientId, contractId: data.contractId, to: data.to, content: final, templateId: tplId });
    res.status(202).json({ status: 'queued' });
  } catch (e) { next(e); }
});

export { router as notificationsRoutes };
