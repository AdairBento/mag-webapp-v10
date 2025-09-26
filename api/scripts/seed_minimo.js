/* global require, process, console */
/* eslint-env node */
/* eslint-disable @typescript-eslint/no-require-imports */
const { PrismaClient, Prisma } = require("@prisma/client");
const prisma = new PrismaClient();

async function ensureTenant(tenantId) {
  await prisma.tenant.upsert({
    where: { id: tenantId },
    update: {},
    create: { id: tenantId, name: "MAG Dev" },
  });
  return tenantId;
}

async function ensureClient(tenantId, data) {
  const existing = await prisma.client.findFirst({
    where: { tenantId, email: data.email || null },
  });
  if (existing) return existing;
  return prisma.client.create({
    data: { tenantId, name: data.name, email: data.email, phone: data.phone },
  });
}

async function ensureVehicle(tenantId, data) {
  const existing = await prisma.vehicle.findFirst({
    where: { tenantId, plate: data.plate },
  });
  if (existing) return existing;
  return prisma.vehicle.create({
    data: {
      tenantId,
      plate: data.plate,
      brand: data.brand,
      model: data.model,
      year: data.year ?? 2024,
      dailyRate: new Prisma.Decimal(data.dailyRate ?? "99.90"),
    },
  });
}

async function main() {
  const tenantId = process.env.TENANT_ID || "00000000-0000-0000-0000-000000000000";

  await ensureTenant(tenantId);

  await ensureClient(tenantId, {
    name: "João Silva",
    email: "joao@mag.dev",
    phone: "31999990001",
  });

  await ensureVehicle(tenantId, {
    plate: "ABC1D23",
    brand: "Fiat",
    model: "Cronos",
    year: 2023,
    dailyRate: "120.00",
  });

  console.log("✅ Seed mínimo aplicado (tenant + 1 cliente + 1 veículo).");
}

main()
  .catch((e) => { console.error("❌ Seed falhou:", e); process.exit(1); })
  .finally(() => prisma.$disconnect());


