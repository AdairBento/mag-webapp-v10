import { Router } from "express";
import { prisma } from "../index";

const router = Router();
router.post("/whatsapp", async (req, res) => {
  try {
    const entries = req.body?.entry || [];
    for (const entry of entries) {
      const changes = entry.changes || [];
      for (const c of changes) {
        const status = c.value?.statuses?.[0];
        if (!status) continue;
        const externalId = status.id as string;
        const st = status.status as "sent" | "delivered" | "read" | "failed";
        await prisma.notificationMessage.updateMany({
          where: { externalId },
          data: {
            status: st,
            deliveredAt: st === "delivered" ? new Date() : undefined,
            readAt: st === "read" ? new Date() : undefined,
          },
        });
      }
    }
    res.sendStatus(200);
  } catch {
    res.sendStatus(200);
  }
});
export { router as webhooksRoutes };
