import { prisma } from "../services/prisma";
import { Prisma } from "@prisma/client";

export async function enqueueNotification(input: Prisma.NotificationMessageUncheckedCreateInput) {
  return prisma.notificationMessage.create({ data: input });
}
