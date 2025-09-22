import { Router } from "express";
import { authRoutes } from "./auth";
import { clientsRoutes } from "./clients";
import { notificationsRoutes } from "./notifications";
import { webhooksRoutes } from "./webhooks";
import { insurersRoutes } from "./insurers";
import { insurancePoliciesRoutes } from "./insurance.policies";
import { incidentsRoutes } from "./incidents";
import { financeRoutes } from "./finance";

export function createRoutes() {
  const r = Router();
  r.use("/auth", authRoutes); // sem tenant para /auth/register-first-admin
  r.use("/webhooks", webhooksRoutes); // sem tenant
  r.use("/clients", clientsRoutes);
  r.use("/notifications", notificationsRoutes);
  r.use("/insurers", insurersRoutes);
  r.use("/insurance/policies", insurancePoliciesRoutes);
  r.use("/incidents", incidentsRoutes);
  r.use("/finance", financeRoutes);
  return r;
}
