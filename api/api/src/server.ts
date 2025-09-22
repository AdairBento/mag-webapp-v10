import express from "express";
import cors from "cors";
import morgan from "morgan";
import clients from "./routes/clients";
import vehicles from "./routes/vehicles";
import rentals from "./routes/rentals";
import maintenanceOrders from "./routes/maintenanceOrders";
import incidents from "./routes/incidents";
import insurers from "./routes/insurers";
import policies from "./routes/policies";
import claims from "./routes/claims";
import financeEntries from "./routes/financeEntries";

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

app.get("/healthz", (_req, res) => res.json({ ok: true }));

app.use("/clients", clients);
app.use("/vehicles", vehicles);
app.use("/rentals", rentals);
app.use("/maintenance-orders", maintenanceOrders);
app.use("/incidents", incidents);
app.use("/insurers", insurers);
app.use("/policies", policies);
app.use("/claims", claims);
app.use("/finance-entries", financeEntries);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(API up on :));