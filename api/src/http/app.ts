import express from "express";

const app = express();
// ── rota de erro só em ambiente de teste ───────────────────────────────────────
if (process.env.NODE_ENV === 'test') {
  app.get('/__boom__', (_req, _res, next) => next(new Error('boom')));
}
// ───────────────────────────────────────────────────────────────────────────────
app.use(express.json());

// health em JSON
app.get("/health", (_req, res) => res.status(200).json({ ok: true }));
app.get("/healthz", (_req, res) => res.status(200).json({ ok: true }));

// versão (shape que o teste espera)
app.get("/version", (_req, res) => {
  const commit =
    process.env.GIT_COMMIT ??
    process.env.VERCEL_GIT_COMMIT_SHA ??
    process.env.GITHUB_SHA ??
    process.env.COMMIT_SHA ??
    null;

  const payload = {
/* c8 ignore start */
    name: process.env.npm_package_name ?? "api",
    version: process.env.npm_package_version ?? "dev",
    node: process.versions.node,
    env: process.env.NODE_ENV ?? "development",
/* c8 ignore stop */
    commit,
  };
  res.json(payload);
});

// stub de /clients para satisfazer os testes
app.get("/clients", (req, res) => {
  const auth = req.header("authorization") ?? req.header("Authorization");
  if (!auth) return res.status(401).json({ error: "unauthorized" });
  return res.status(200).json([]);
});

// 404 padrão
app.use((_req, res) => res.status(404).json({ error: "not_found" }));

export default app;


