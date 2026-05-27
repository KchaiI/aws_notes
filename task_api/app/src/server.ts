import "./lib/env.js";
import Fastify, { type FastifyError } from "fastify";
import sensible from "@fastify/sensible";
import { tasksRoutes } from "./routes/tasks.js";
import { healthRoutes } from "./routes/health.js";
import { imagesRoutes } from "./routes/images.js";
import { csvExportsRoutes } from "./routes/csv_exports.js";
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

// ─────────────────────────────────────────────────────────────
// エラーハンドラー
//
// 設計理由:
//   - ルートは throw するだけ / reply.code(4xx).send() するだけでよく、
//     ログ出力の責務をここに集約する（Single Responsibility）
//   - pino が JSON 形式で出力するため、CloudWatch Insights で
//     「level >= 50」のフィルタだけでサーバーエラーを抽出できる
//   - 5xx: error レベル (level=50) → アラート対象
//   - 4xx: warn レベル (level=40) → 監視はするが通知不要
//   - reqId フィールドで「リクエストログ ↔ エラーログ」を紐付け可能
// ─────────────────────────────────────────────────────────────
fastify.setErrorHandler((error: FastifyError, request, reply) => {
  const statusCode = error.statusCode ?? 500;

  if (statusCode >= 500) {
    request.log.error(
      {
        err: {
          message: error.message,
          stack: error.stack,
          code: error.code,
        },
        statusCode,
        method: request.method,
        url: request.url,
      },
      "Server error",
    );
  } else {
    request.log.warn(
      { statusCode, method: request.method, url: request.url, message: error.message },
      "Client error",
    );
  }

  reply.code(statusCode).send({
    statusCode,
    error: error.name,
    message: error.message,
  });
});

// ルート
await fastify.register(tasksRoutes, { prefix: "/api" });
await fastify.register(imagesRoutes, { prefix: "/api" });
await fastify.register(csvExportsRoutes, { prefix: "/api" });
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