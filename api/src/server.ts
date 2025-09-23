import health from "./http/health";
import express from "express";
import cors from "cors";
import morgan from "morgan";

import clients from "./routes/clients";
import vehicles from "./routes/vehicles";
import rentals from "./routes/rentals";
import maintenanceOrders from "./routes/maintenanceOrders";
import dashboard from "./routes/dashboard";

export const app = express();
app.use(health);
// healthcheck simples
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

app.use("/clients", clients);
app.use("/vehicles", vehicles);
app.use("/rentals", rentals);
app.use("/maintenance-orders", maintenanceOrders);
app.use("/dashboard", dashboard);

const PORT = Number(process.env.PORT) || 3001;
if (process.env.NODE_ENV !== "test") {
  if (process.env.NODE_ENV !== "test") {
    if (process.env.NODE_ENV !== "test") {
      app.listen(PORT, () =>
        console.log(`Sistema MAG v10 API rodando em http://127.0.0.1:${PORT}`),
      );
    }
  }
}
