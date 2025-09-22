const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  // Encontra (ou cria) um tenant 'dev'
  const tenant = await prisma.tenant.upsert({
    where: { id: process.env.TENANT_ID || "00000000-0000-0000-0000-000000000000" },
    update: {},
    create: { id: process.env.TENANT_ID || "00000000-0000-0000-0000-000000000000", name: "dev" }
  });

  const client = await prisma.client.upsert({
    where: { id: "11111111-1111-1111-1111-111111111111" },
    update: {},
    create: { id:"11111111-1111-1111-1111-111111111111", tenantId: tenant.id, name: "Cliente Demo", email: "cliente@demo.local", phone: "31999990000" }
  });

  const vehicle = await prisma.vehicle.upsert({
    where: { id: "22222222-2222-2222-2222-222222222222" },
    update: {},
    create: { id:"22222222-2222-2222-2222-222222222222", tenantId: tenant.id, plate: "ABC1D23", brand: "Fiat", model: "Cronos", type: "car", status: "available" }
  });

  const rental = await prisma.rental.upsert({
    where: { id: "33333333-3333-3333-3333-333333333333" },
    update: {},
    create: { id:"33333333-3333-3333-3333-333333333333", tenantId: tenant.id, clientId: client.id, vehicleId: vehicle.id, status: "active" }
  });

  const maint = await prisma.maintenanceOrder.upsert({
    where: { id: "44444444-4444-4444-4444-444444444444" },
    update: {},
    create: { id:"44444444-4444-4444-4444-444444444444", tenantId: tenant.id, assetId: vehicle.id, type: "preventive", status: "open" }
  });

  const insurer = await prisma.insurer.upsert({
    where: { id: "55555555-5555-5555-5555-555555555555" },
    update: {},
    create: { id:"55555555-5555-5555-5555-555555555555", tenantId: tenant.id, type: "insurance", name: "Seguradora Demo", document: "12.345.678/0001-90" }
  });

  const policy = await prisma.insurancePolicy.upsert({
    where: { id: "66666666-6666-6666-6666-666666666666" },
    update: {},
    create: { id:"66666666-6666-6666-6666-666666666666", tenantId: tenant.id, assetId: vehicle.id, insurerId: insurer.id, number: "POL-0001", status: "active" }
  });

  console.log("Seed aplicado com sucesso.");
}

main().catch(e => {
  console.error(e);
  process.exit(1);
}).finally(() => prisma.());