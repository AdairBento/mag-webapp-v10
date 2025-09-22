import { Router } from "express";
import { prisma } from "../services/prisma";
const r = Router();

r.get("/", async (_req, res) => {
  const data = await prisma.maintenanceOrder.findMany({ take: 200, orderBy: { id: "desc" } as any });
  res.json(data);
});

r.post("/", async (req, res) => {
  const { tenantId, assetId, type } = req.body || {};
  if (!tenantId || !assetId) return res.status(400).json({ error: "tenantId e assetId são obrigatórios" });
  const created = await prisma.maintenanceOrder.create({
    data: { tenantId, assetId, type: type || "preventive" } as any
  });
  res.status(201).json(created);
});

r.put("/:id/close", async (req, res) => {
  const { id } = req.params;
  const updated = await prisma.maintenanceOrder.update({
    where: { id },
    data: { closedAt: new Date() } as any
  });
  res.json(updated);
});

export default r;
