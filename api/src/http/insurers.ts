import { Router } from "express";
import { prisma } from "../index";
import { z } from "zod";

const router = Router();
const upsert = z.object({
  name: z.string().min(1),
  type: z.enum(["bank", "association", "insurer"]),
  doc: z.string().optional(),
  email: z.string().email().optional(),
  phone: z.string().optional(),
});

router.get("/", async (req, res, next) => {
  try {
    const data = await prisma.insurer.findMany({
      where: { tenantId: req.tenantId! },
      orderBy: { name: "asc" },
    });
    res.json({ data });
  } catch (e) {
    next(e);
  }
});
router.post("/", async (req, res, next) => {
  try {
    const payload = upsert.parse(req.body);
    const item = await prisma.insurer.create({ data: { ...payload, tenantId: req.tenantId! } });
    res.status(201).json(item);
  } catch (e) {
    next(e);
  }
});
router.patch("/:id", async (req, res, next) => {
  try {
    const payload = upsert.partial().parse(req.body);
    const { id } = req.params;
    const updated = await prisma.insurer.update({ where: { id }, data: payload });
    res.json(updated);
  } catch (e) {
    next(e);
  }
});
export { router as insurersRoutes };
