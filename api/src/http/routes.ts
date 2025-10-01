import { Router } from "express";
import clientsRoutes from "../routes/clients";
import { notificationsRoutes } from "./notifications";
import { utilsRoutes } from "./utils";
import { insurersRoutes } from "./insurers";
import { insurancePoliciesRoutes } from "./insurance.policies";
import { incidentsRoutes } from "./incidents";
import { financeRoutes } from "./finance";

export function createRoutes() {
  const r = Router();
  r.use("/utils", utilsRoutes); // público
// sem tenant para /auth/register-first-admin
// sem tenant
  r.use("/clients", clientsRoutes);
  r.use("/notifications", notificationsRoutes);
  r.use("/insurers", insurersRoutes);
  r.use("/insurance/policies", insurancePoliciesRoutes);
  r.use("/incidents", incidentsRoutes);
  r.use("/finance", financeRoutes);
  return r;
}



