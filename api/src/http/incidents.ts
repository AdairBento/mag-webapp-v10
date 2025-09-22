import { Router } from "express";
import { prisma } from "../services/prisma";

const r = Router();

r.get("/", async (_req, res) => {
  // usa occurredAt; o `as any` evita erro de tipagem caso o campo tenha outro nome no schema
  const items = await prisma.incident.findMany({ orderBy: { occurredAt: "desc" } as any });
  res.json(items);
});

r.post("/", async (req, res) => {
  try {
    const { tenantId, vehicleId, assetId, description, type, occurredAt } = req.body ?? {};
    if (!tenantId) return res.status(400).json({ error: "tenantId é obrigatório" });
    const fk = (vehicleId ?? assetId);
    if (!fk) return res.status(400).json({ error: "Informe o identificador do veículo (vehicleId)" });

    // monta o objeto de criação de forma tolerante:
    // - define tenantId/description/occurredAt
    // - seta vehicleId OU assetId somente se vierem no body
    // - seta type somente se vier no body (sem enum do Prisma)
    const data: any = {
      tenantId,
      description,
      occurredAt: occurredAt ? new Date(occurredAt) : new Date(),
    };
    if (typeof vehicleId !== "undefined") (data as any).vehicleId = vehicleId;
    if (typeof assetId   !== "undefined") (data as any).assetId   = assetId;
    if (typeof type      !== "undefined") (data as any).type      = type;

    const created = await prisma.incident.create({ data });
    res.status(201).json(created);
  } catch (e: any) {
    res.status(400).json({ error: e.message });
  }
});

export const incidentsRoutes = r;
export default r;
