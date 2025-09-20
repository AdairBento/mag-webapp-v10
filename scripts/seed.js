const { PrismaClient } = require("@prisma/client");
const bcrypt = require("bcryptjs");
const prisma = new PrismaClient();

async function main() {
  const email = process.env.SEED_EMAIL || "cliente.demo@mag.dev";
  const passwordPlain = process.env.SEED_PASSWORD || "mag123456";

  console.log("🌱 Seed v3 — compatível com schema atual");

  // ===== Tenant: sem slug =====
  let tenant = await prisma.tenant.findFirst({ where: { name: "MAG Dev" } }).catch(()=>null);
  if (!tenant) {
    tenant = await prisma.tenant.create({ data: { name: "MAG Dev" } });
  }
  console.log("✅ Tenant OK:", tenant.name || tenant.id);

  // ===== User: campo obrigatório 'password'; sem 'role';
  // relação via join 'tenants' (ou 'usersTenants' dependendo do schema) =====
  const passwordHash = await bcrypt.hash(passwordPlain, 10);

  // Tenta usando a relação 'tenants'
  try {
    await prisma.user.upsert({
      where: { email },
      update: {},
      create: {
        email,
        name: "Cliente Demo",
        password: passwordHash, // hash no campo 'password'
        tenants: {              // relação via join model
          create: { tenant: { connect: { id: tenant.id } } }
        }
      }
    });
    console.log("✅ Usuário OK (via 'tenants'):", email);
  } catch (e1) {
    console.warn("Tentativa A (tenants) falhou:", e1?.message || String(e1));
    // Alternativa: a relação pode se chamar 'usersTenants'
    try {
      await prisma.user.upsert({
        where: { email },
        update: {},
        create: {
          email,
          name: "Cliente Demo",
          password: passwordHash,
          usersTenants: {
            create: { tenant: { connect: { id: tenant.id } } }
          }
        }
      });
      console.log("✅ Usuário OK (via 'usersTenants'):", email);
    } catch (e2) {
      console.error("❌ Seed falhou:", e2?.message || String(e2));
      process.exit(1);
    }
  }

  console.log("🌱 Seed concluído.");
}

main()
  .catch((e)=>{ console.error("Seed falhou:", e); process.exit(1); })
  .finally(async ()=>{ await prisma.$disconnect(); });
