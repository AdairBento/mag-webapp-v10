import { Router } from "express";
import { prisma } from "../services/prisma";
import type { Prisma } from "@prisma/client";

const r = Router();

r.get("/", async (_req, res) => {
  const items = await prisma.insurancePolicy.findMany({ orderBy: { createdAt: "desc" } as any });
  res.json(items);
});

r.post("/", async (req, res) => {
  try {
    const { tenantId, vehicleId, assetId, startDate, startAt, endDate, endAt, premium, active } =
      req.body ?? {};
    if (!tenantId) return res.status(400).json({ error: "tenantId é obrigatório" });
    const fk = vehicleId ?? assetId;
    if (!fk)
      return res.status(400).json({ error: "Informe o identificador do veículo (vehicleId)" });

    const startAny = startDate ?? startAt;
    const endAny = endDate ?? endAt;

    const data: any = {
      tenantId: tenantId,
      assetId: fk,
    };

    const created = await prisma.insurancePolicy.create({ data });
    res.status(201).json(created);
  } catch (e: any) {
    res.status(400).json({ error: e.message });
  }
});

export const insurancePoliciesRoutes = r;
export default r;
