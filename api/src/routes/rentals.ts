import { Router } from "express";
import { prisma } from "../services/prisma";
import { Prisma } from "@prisma/client";

const r = Router();

r.get("/", async (req, res) => {
  const page = Math.max(parseInt(String(req.query.page ?? "1"), 10), 1);
  const limit = Math.max(parseInt(String(req.query.limit ?? "20"), 10), 1);
  const skip = (page - 1) * limit;

  const [total, data] = await Promise.all([
    prisma.rental.count(),
    prisma.rental.findMany({
      skip,
      take: limit,
      orderBy: { createdAt: "desc" } as any,
      include: { client: true, vehicle: true },
    }),
  ]);
  res.json({ page, limit, total, data });
});

r.post("/", async (req, res) => {
  const { tenantId, clientId, vehicleId, startDate } = req.body || {};
  if (!tenantId || !clientId || !vehicleId) {
    return res.status(400).json({ error: "tenantId, clientId e vehicleId são obrigatórios" });
  }
  try {
    const v = await prisma.vehicle.findUnique({ where: { id: vehicleId } });
    if (!v) return res.status(404).json({ error: "Veículo não encontrado" });

    const existing = await prisma.rental.findFirst({ where: { vehicleId, endDate: null } });
    if (existing) return res.status(409).json({ error: "Veículo já está alugado" });

    const rental = await prisma.$transaction(async (tx) => {
      await tx.vehicle.update({
        where: { id: vehicleId },
        data: { status: "rented" as any },
      });
      return tx.rental.create({
        data: {
          tenantId,
          clientId,
          vehicleId,
          startDate: startDate ? new Date(startDate) : new Date(),
          dailyRate: (v as any).dailyRate ?? "0",
          status: "open" as any,
        } as any,
      });
    });

    res.status(201).json(rental);
  } catch (e: any) {
    res.status(400).json({ error: e.message || "Falha ao abrir locação" });
  }
});

r.put("/:id/close", async (req, res) => {
  const { id } = req.params;
  try {
    const updated = await prisma.$transaction(async (tx) => {
      const rental = await tx.rental.findUnique({ where: { id } });
      if (!rental) throw new Error("Locação não encontrada");
      if (rental.endDate) throw new Error("Locação já encerrada");

      const now = new Date();
      const ms = now.getTime() - rental.startDate.getTime();
      const days = Math.max(1, Math.ceil(ms / (1000 * 60 * 60 * 24)));
      const rate = new Prisma.Decimal(rental.dailyRate as any);
      const finalAmount = rate.mul(days);

      const r = await tx.rental.update({
        where: { id },
        data: { endDate: now, status: "closed" as any, finalAmount } as any,
      });

      await tx.vehicle.update({
        where: { id: r.vehicleId },
        data: { status: "available" as any },
      });
      return r;
    });

    res.json(updated);
  } catch (e: any) {
    res.status(400).json({ error: e.message || "Falha ao encerrar locação" });
  }
});

export default r;
