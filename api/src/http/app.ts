import express from "express";
import clientsRouter from "../routes/clients";

const app = express();

// rota de erro só em ambiente de teste
if (process.env.NODE_ENV === "test") {
  app.get("/__boom__", (_req, _res, next) => next(new Error("boom")));
}

app.use(express.json());

// health
app.get("/health", (_req, res) => res.status(200).json({ ok: true }));
app.get("/healthz", (_req, res) => res.status(200).json({ ok: true }));

// versão (shape esperado pelo teste)
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

// monta o router real em /clients (auth fica no próprio router)
app.use("/clients", clientsRouter);

// 404 padrão (depois de todas as rotas)
app.use((_req, res) => res.status(404).json({ error: "not_found" }));

export default app;
