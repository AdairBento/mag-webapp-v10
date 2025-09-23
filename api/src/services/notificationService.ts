import { prisma } from "../services/prisma";
import { Prisma } from "@prisma/client";

type NotificationMessageCreateInput = Parameters<
  typeof prisma.notificationMessage.create
>[0] extends { data: infer D }
  ? D
  : never;
export async function enqueueNotification(input: NotificationMessageCreateInput) {
  return prisma.notificationMessage.create({ data: input });
}
