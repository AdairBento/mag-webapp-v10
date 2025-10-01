import { Router } from "express";
import { lookupCep } from "../utils/cep";

/**
 * Rotas utilitárias (públicas).
 * GET /api/utils/cep/:cep
 */
export const utilsRoutes = Router();

utilsRoutes.get("/cep/:cep", async (req, res) => {
  try {
    const addr = await lookupCep(req.params.cep);
    res.json(addr);
  } catch (e: any) {
    res.status(400).json({ error: e.message || "CEP inválido" });
  }
});

export default utilsRoutes;
