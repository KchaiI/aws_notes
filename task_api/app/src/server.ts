import "./lib/env.js";
import Fastify from "fastify";
import sensible from "@fastify/sensible";
import { tasksRoutes } from "./routes/tasks.js";
import { healthRoutes } from "./routes/health.js";
import { imagesRoutes } from "./routes/images.js";
import { prisma } from "./lib/prisma.js";

const PORT = Number(process.env.PORT ?? 3000);
const HOST = process.env.HOST ?? "0.0.0.0";

const fastify = Fastify({
  logger: {
    level: process.env.LOG_LEVEL ?? "info",
    transport:
      process.env.NODE_ENV !== "production"
        ? { target: "pino-pretty" }
        : undefined,
  },
});

// プラグイン
await fastify.register(sensible);

// ルート
await fastify.register(tasksRoutes, { prefix: "/api" });
await fastify.register(imagesRoutes, { prefix: "/api" });
await fastify.register(healthRoutes);

// グレースフルシャットダウン
const closeGracefully = async (signal: string) => {
  fastify.log.info({ signal }, "Shutting down gracefully");
  await fastify.close();
  await prisma.$disconnect();
  process.exit(0);
};
process.on("SIGTERM", () => closeGracefully("SIGTERM"));
process.on("SIGINT", () => closeGracefully("SIGINT"));

try {
  await fastify.listen({ port: PORT, host: HOST });
} catch (err) {
  fastify.log.error(err);
  process.exit(1);
}