import { Router } from "express";
import { prisma } from "../services/prisma";

const r = Router();

r.get("/summary", async (_req, res) => {
  try {
    const [clients, vehiclesTotal, vehiclesFree, rentalsActive] = await Promise.all([
      prisma.client.count(),
      prisma.vehicle.count(),
      prisma.vehicle.count({ where: { status: "available" as any } }),
      prisma.rental.count({ where: { endDate: null } }),
    ]);

    let maintenanceOpen = 0;
    try {
      maintenanceOpen = await prisma.maintenanceOrder.count();
    } catch {
      maintenanceOpen = await prisma.maintenanceOrder.count();
    }

    const alerts = [
      { id: "al-1", text: "CNH do cliente C002 vence em 15 dias." },
      { id: "al-2", text: "Revisão do veículo ABC-1D23 em 1.000 km." },
    ];

    res.json({
      clients,
      vehicles: vehiclesTotal,
      vehiclesFree,
      rentalsActive,
      maintenanceOpen,
      alertsCount: alerts.length,
      alerts,
    });
  } catch (e: any) {
    console.error("Dashboard summary error:", e);
    res.status(500).json({ error: e.message || "Erro no dashboard" });
  }
});

export default r;

