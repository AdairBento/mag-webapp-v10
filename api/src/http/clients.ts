import { Router } from "express";
import auth from "../middleware/auth";
import { listClients } from "../services/clients";

const router = Router();

router.get("/clients", auth, async (_req, res) => {
  const data = await listClients();
  return res.json({ data });
});

export default router;
