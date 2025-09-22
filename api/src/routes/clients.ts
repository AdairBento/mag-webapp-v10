import { Router } from "express";
import { prisma } from "../services/prisma";
const r = Router();

r.get("/", async (req, res) => {
  const q = String(req.query.q || "").trim();
  const where: any = q
    ? {
        OR: [
          { name: { contains: q, mode: "insensitive" } },
          { email: { contains: q, mode: "insensitive" } },
          { phone: { contains: q, mode: "insensitive" } },
        ],
      }
    : {};
  const data = await prisma.client.findMany({ where, take: 200, orderBy: { name: "asc" } as any });
  res.json(data);
});

r.post("/", async (req, res) => {
  const { tenantId, name, email, phone } = req.body || {};
  if (!tenantId || !name)
    return res.status(400).json({ error: "tenantId e name são obrigatórios" });
  const created = await prisma.client.create({ data: { tenantId, name, email, phone } });
  res.status(201).json(created);
});

export default r;
