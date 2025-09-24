import { Router } from "express";
import { prisma } from "../services/prisma";
const r = Router();

r.get("/", async (_req, res) => {
  const data = await prisma.vehicle.findMany({ take: 200, orderBy: { plate: "asc" } as any });
  res.json(data);
});

r.post("/", async (req, res) => {
  const { tenantId, plate, brand, model, year, dailyRate } = req.body || {};
  if (!tenantId || !plate)
    return res.status(400).json({ error: "tenantId e plate são obrigatórios" });
  const created = await prisma.vehicle.create({
    data: { tenantId, plate, brand, model, year, dailyRate } as any,
  });
  res.status(201).json(created);
});

export default r;
