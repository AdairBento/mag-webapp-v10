import { Router } from "express";
import auth from "../middleware/auth";
import { listClients } from "../services/clients";

const router = Router();
router.use(auth); // protege todas as rotas deste router

router.get("/", async (_req, res) => {
  const data = await listClients();
  return res.json({ data });
});

export default router;