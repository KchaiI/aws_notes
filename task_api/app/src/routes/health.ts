import type { FastifyInstance } from "fastify";
import { prisma } from "../lib/prisma.js";



export async function healthRoutes(fastify: FastifyInstance) {
  // 軽量ヘルスチェック(プロセスが生きていればOK)
  fastify.get("/health", async () => {
    return { status: "ok" };
  });

  // DB含めた詳細ヘルスチェック
  fastify.get("/health/db", async (request, reply) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      return { status: "ok", db: "connected" };
    } catch (error) {
      request.log.error({ err: error }, "DB health check failed");
      return reply.code(503).send({ status: "error", db: "disconnected" });
    }
  });
}