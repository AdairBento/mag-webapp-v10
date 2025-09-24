import type { Router } from "express";

const router = Router();

/**
 * Endpoint sem dependência de DB.
 * Usa envs do NPM quando disponível e tem fallbacks seguros.
 */
router.get("/", (_req, res) => {
  const payload = {
    name: process.env.npm_package_name ?? "api",
    version: process.env.npm_package_version ?? "0.0.0-dev",
    commit: process.env.APP_COMMIT ?? null,
    node: process.version,
    env: process.env.NODE_ENV ?? "development",
  };
  res.json(payload);
});

export default router;
