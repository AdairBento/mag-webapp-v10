import { prisma } from "../services/prisma";
import { Prisma } from "@prisma/client";

export async function enqueueNotification(
  input: Parameters<typeof prisma.notificationMessage.create>[0]["data"],
) {
  return prisma.notificationMessage.create({ data: input });
}
