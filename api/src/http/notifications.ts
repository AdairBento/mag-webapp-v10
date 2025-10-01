import { Router } from "express";
import { prisma } from "../services/prisma";

const r = Router();

r.get("/", async (_req, res) => {
  const items = await prisma.notificationMessage.findMany({
    orderBy: { createdAt: "desc" } as any,
  });
  res.json(items);
});

r.post("/", async (req, res) => {
  try {
    const {
      tenantId,
      channel,
      kind,
      type,
      subject: _subject,
      title: _title,
      body: _body,
      content,
      active: _active,
    } = req.body ?? {};
    if (!tenantId) return res.status(400).json({ error: "tenantId é obrigatório" });
    if (!channel) return res.status(400).json({ error: "channel é obrigatório" });
    const kindOrType = kind ?? type;
    if (!kindOrType) return res.status(400).json({ error: "kind é obrigatório" });

    const data: any = {
      tenantId: tenantId,
      channel: channel,
      kind: kindOrType,
      content: content,
    };

    const created = await prisma.notificationMessage.create({ data });
    res.status(201).json(created);
  } catch (e: any) {
    res.status(400).json({ error: e.message });
  }
});

export const notificationsRoutes = r;
export default r;
