// seed.js — cria Tenant "MAG Dev", usuário demo e vínculo user↔tenant
// Detecta enum/tabela de role; aceita SEED_ROLE=admin|ADMIN|...
const { PrismaClient } = require("@prisma/client");
const bcrypt = require("bcryptjs");
const prisma = new PrismaClient();

// Helpers PG
async function pgEnumValues(enumNameLike) {
  try {
    const rows = await prisma.$queryRawUnsafe(
      `
      SELECT e.enumlabel AS val
      FROM pg_type t
      JOIN pg_enum e ON t.oid = e.enumtypid
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public'
        AND (lower(t.typname) = lower($1)
             OR lower(t.typname) LIKE lower($1) || '%')
      ORDER BY e.enumsortorder
    `,
      enumNameLike
    );
    return rows.map(r => String(r.val));
  } catch {
    return [];
  }
}
async function tableExists(table) {
  try {
    const r = await prisma.$queryRawUnsafe(
      `
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND lower(table_name) = lower($1)
      ) AS ok
    `,
      table
    );
    return !!r?.[0]?.ok;
  } catch {
    return false;
  }
}
async function columnExists(table, column) {
  try {
    const r = await prisma.$queryRawUnsafe(
      `
      SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND lower(table_name) = lower($1)
          AND lower(column_name) = lower($2)
      ) AS ok
    `,
      table,
      column
    );
    return !!r?.[0]?.ok;
  } catch {
    return false;
  }
}

async function main() {
  const email = process.env.SEED_EMAIL || "cliente.demo@mag.dev";
  const passwordPlain = process.env.SEED_PASSWORD || "mag123456";
  const preferRole = (process.env.SEED_ROLE || "").trim(); // ex.: admin

  console.log("🌱 Seed — detecta Role via Postgres (enum) ou modelo");

  // Tenant
  let tenant = await prisma.tenant.findFirst({ where: { name: "MAG Dev" } }).catch(() => null);
  if (!tenant) tenant = await prisma.tenant.create({ data: { name: "MAG Dev" } });
  console.log("✅ Tenant OK:", tenant.name || tenant.id);

  // User (sem vínculo primeiro)
  const passwordHash = await bcrypt.hash(passwordPlain, 10);
  const user = await prisma.user.upsert({
    where: { email },
    update: {},
    create: { email, name: "Cliente Demo", password: passwordHash },
  });
  console.log("✅ User OK:", user.email);

  // Descobrir possíveis roles (enum role + tabela Role)
  let enumVals = await pgEnumValues("role");
  if (preferRole) {
    enumVals = [preferRole, ...enumVals.filter(v => v !== preferRole)];
  } else if (enumVals.includes("ADMIN")) {
    enumVals = ["ADMIN", ...enumVals.filter(v => v !== "ADMIN")];
  } else if (enumVals.includes("admin")) {
    enumVals = ["admin", ...enumVals.filter(v => v !== "admin")];
  }

  const hasRoleTable = await tableExists("Role");
  let roleRow = null;
  if (hasRoleTable) {
    const common = preferRole ? [preferRole] : ["ADMIN", "admin", "Owner", "OWNER", "Admin", "MANAGER", "USER"];
    try {
      const found = await prisma.$queryRawUnsafe(
        `SELECT * FROM "Role" WHERE COALESCE(name,'') <> '' AND name = ANY($1) LIMIT 1`,
        common
      );
      roleRow = found?.[0] || null;
    } catch {}
    if (!roleRow) {
      try {
        const anyRow = await prisma.$queryRawUnsafe(`SELECT * FROM "Role" LIMIT 1`);
        roleRow = anyRow?.[0] || null;
      } catch {}
    }
    if (!roleRow && (await columnExists("Role", "name"))) {
      try {
        const toCreate = preferRole || "ADMIN";
        const created = await prisma.$queryRawUnsafe(
          `INSERT INTO "Role"(name) VALUES ($1) RETURNING *`,
          toCreate
        );
        roleRow = created?.[0] || null;
        console.log(`ℹ️ Criado Role(name='${toCreate}') na tabela.`);
      } catch (e) {
        console.warn("⚠️ Não consegui criar linha em Role:", e?.message || String(e));
      }
    }
  }

  const baseLink = { tenant: { connect: { id: tenant.id } } };
  const attempts = [];

  // a) enum direto
  for (const val of enumVals) attempts.push({ desc: `enum direto: ${val}`, data: { ...baseLink, role: val } });
  // b) enum { set: ... }
  for (const val of enumVals) attempts.push({ desc: `enum via { set: ${val} }`, data: { ...baseLink, role: { set: val } } });
  // c) modelo Role connect
  if (roleRow) {
    if ("id" in roleRow) {
      attempts.push({
        desc: `modelo Role connect por id=${roleRow.id}`,
        data: { ...baseLink, role: { connect: { id: roleRow.id } } },
      });
    }
    if ("name" in roleRow && roleRow.name) {
      attempts.push({
        desc: `modelo Role connect por name=${roleRow.name}`,
        data: { ...baseLink, role: { connect: { name: roleRow.name } } },
      });
    }
  }
  // d) sem role (se não for obrigatório)
  attempts.push({ desc: "sem role (fallback final)", data: { ...baseLink } });

  let linked = false;
  let lastErr = null;
  for (const a of attempts) {
    try {
      await prisma.user.update({
        where: { id: user.id },
        data: { tenants: { create: a.data } },
      });
      console.log("✅ Vínculo criado com:", a.desc);
      linked = true;
      break;
    } catch (e) {
      const msg = e?.message || String(e);
      if (/P2002|Unique constraint/i.test(msg)) {
        console.log("ℹ️ Vínculo já existia, ok.");
        linked = true;
        break;
      }
      lastErr = e;
      console.warn("↩️ Falhou:", a.desc, "→", msg);
    }
  }

  if (!linked) {
    console.error("❌ Não foi possível criar o vínculo user↔tenant. Último erro:", lastErr?.message || String(lastErr));
    process.exit(1);
  }

  console.log("🌱 Seed concluído.");
}

main()
  .catch(e => {
    console.error("Seed falhou:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
