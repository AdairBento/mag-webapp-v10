import { Router } from "express";

const router = Router();

router.get("/health", (_req, res) => res.status(200).json({ ok: true }));
router.get("/healthz", (_req, res) => res.json({ ok: true }));

export default router;
