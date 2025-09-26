import express from "express";
import cors from "cors";
import helmet from "helmet";
import dotenv from "dotenv";
import { PrismaClient } from "@prisma/client";
import { createRoutes } from "./http/routes";
import { errorHandler } from "./middleware/errorHandler";
import authMiddleware from "./middleware/authMiddleware";
import { tenantMiddleware } from "./middleware/tenantMiddleware";
import swaggerUi from "swagger-ui-express";
import swaggerJsdoc from "swagger-jsdoc";

dotenv.config();
const app = express();
const prisma = new PrismaClient();
const PORT = Number(process.env.PORT) || 3000;
const API_PREFIX = "/api";

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true }));

app.get("/health", (_req, res) =>
  res.json({ status: "OK", ts: new Date().toISOString(), v: "10.0.0" }),
);
app.get("/metrics", (_req, res) =>
  res.json({
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    ts: new Date().toISOString(),
  }),
);

const swaggerSpec = swaggerJsdoc({
  definition: { openapi: "3.0.3", info: { title: "MAG WEB APP V10", version: "10.0.0" } },
  apis: ["./src/http/**/*.ts"],
});
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec) as any);

app.use(API_PREFIX, authMiddleware, tenantMiddleware, createRoutes());
app.use(errorHandler);
app.use("*", (req, res) =>
  res.status(404).json({
    error: { code: "NOT_FOUND", message: `Route ${req.method} ${req.originalUrl} not found` },
  }),
);

process.on("SIGTERM", async () => {
  await prisma.$disconnect();
  process.exit(0);
});

app.listen(PORT, () => {
  console.log(`🚀 MAG V10 API on :${PORT}`);
  console.log(`📊 Health:  http://localhost:${PORT}/health`);
  console.log(`📚 Swagger: http://localhost:${PORT}/api-docs`);
});

export { app, prisma };


