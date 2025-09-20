import express from "express";
import cors from "cors";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";

const app = express();
const prisma = new PrismaClient();

const PORT = Number(process.env.PORT || 3001);
const JWT_SECRET = process.env.JWT_SECRET || "changeme_super_secret_key";

// CORS: defina CORS_ORIGIN no .env (ex.: http://127.0.0.1:3000,http://localhost:3000)
const allowed = (process.env.CORS_ORIGIN || "")
  .split(",")
  .map(s => s.trim())
  .filter(Boolean);

app.use(cors({ origin: allowed.length ? allowed : true }));
app.use(express.json());

// ── auth middleware ───────────────────────────────────────────────────────────────
function auth(req: any, res: any, next: any) {
  const h = req.headers?.authorization || "";
  if (!h.startsWith("Bearer ")) {
    return res.status(401).json({ ok: false, error: "missing bearer token" });
  }
  const token = h.slice(7);
  try {
    req.auth = jwt.verify(token, JWT_SECRET); // { sub, email, tenantId, iat, exp }
    next();
  } catch (e: any) {
    return res
      .status(401)
      .json({ ok: false, error: "invalid token", detail: e?.message || String(e) });
  }
}

// ── healthz ──────────────────────────────────────────────────────────────────────
app.get("/healthz", async (_req, res) => {
  try {
    const rows: any = await prisma.$queryRaw`SELECT NOW() as now`; // seguro
    res.json({
      ok: true,
      db: "up",
      now: rows?.[0]?.now ?? null,
      env: {
        node: process.version,
        port: PORT,
        node_env: process.env.NODE_ENV || null,
      },
    });
  } catch (e: any) {
    res.status(500).json({ ok: false, db: "down", error: e?.message || String(e) });
  }
});

// ── login ────────────────────────────────────────────────────────────────────────
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ ok: false, error: "email e password são obrigatórios" });
    }

    const user: any = await prisma.user
      .findUnique({
        where: { email },
        include: {
          tenants: { select: { tenantId: true, tenant: { select: { id: true } } } },
        },
      })
      .catch(() => null);

    if (!user?.password) {
      return res.status(401).json({ ok: false, error: "credenciais inválidas" });
    }

    const ok = await bcrypt.compare(String(password), String(user.password));
    if (!ok) return res.status(401).json({ ok: false, error: "credenciais inválidas" });

    const tenantId = user.tenants?.[0]?.tenantId ?? user.tenants?.[0]?.tenant?.id ?? null;

    const token = jwt.sign({ sub: user.id, email: user.email, tenantId }, JWT_SECRET, {
      expiresIn: "12h",
    });

    res.json({ ok: true, token, user: { id: user.id, email: user.email, name: user.name }, tenantId });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: e?.message || String(e) });
  }
});

// ── rotas protegidas ─────────────────────────────────────────────────────────────
app.get("/me", auth, (req: any, res) => {
  res.json({ ok: true, auth: req.auth });
});

app.get("/api/users", auth, async (_req, res) => {
  const rows = await prisma.user.findMany({ select: { id: true, email: true, name: true } });
  res.json(rows);
});

// ── debug de rotas (dev) ─────────────────────────────────────────────────────────
app.get("/debug/routes", (_req, res) => {
  const routes: Array<{ methods: string; path: string }> = [];
  // @ts-ignore (apenas dev)
  app._router?.stack?.forEach((layer: any) => {
    if (layer?.route?.path) {
      const methods = Object.keys(layer.route.methods || {})
        .map(m => m.toUpperCase())
        .join(",");
      routes.push({ methods, path: layer.route.path });
    }
  });
  res.json(routes);
});

// ── 404 & erro ───────────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ ok: false, error: "not_found" }));
app.use((err: any, _req: any, res: any, _next: any) => {
  console.error(err);
  res.status(500).json({ ok: false, error: "internal_error" });
});

app.listen(PORT, () => console.log(`MAG v10 API on http://127.0.0.1:${PORT}`));
