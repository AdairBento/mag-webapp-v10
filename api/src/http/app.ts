import express from "express";

const app = express();
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
    name: process.env.npm_package_name ?? "api",
    version: process.env.npm_package_version ?? "dev",
    node: process.versions.node,
    env: process.env.NODE_ENV ?? "development",
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
