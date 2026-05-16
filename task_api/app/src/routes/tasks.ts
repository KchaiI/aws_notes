import type { FastifyInstance } from "fastify";
import { prisma } from "../lib/prisma.js";
import {
  TaskInputSchema,
  TaskIdParamSchema,
  TaskListQuerySchema,
} from "../lib/schemas.js";

export async function tasksRoutes(fastify: FastifyInstance) {
  // GET /tasks - 一覧
  fastify.get("/tasks", async (request, reply) => {
    const query = TaskListQuerySchema.parse(request.query);

    const tasks = await prisma.task.findMany({
      where: query.status ? { status: query.status } : undefined,
      orderBy: { id: "asc" },
    });

    return tasks;
  });

  // POST /tasks - 作成
  fastify.post("/tasks", async (request, reply) => {
    const parseResult = TaskInputSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.code(400).send({
        message: `バリデーションエラー: ${parseResult.error.issues
          .map((i) => i.message)
          .join(", ")}`,
      });
    }

    const task = await prisma.task.create({
      data: parseResult.data,
    });

    return reply.code(201).send(task);
  });

  // GET /tasks/:id - 取得
  fastify.get("/tasks/:id", async (request, reply) => {
    const params = TaskIdParamSchema.parse(request.params);

    const task = await prisma.task.findUnique({ where: { id: params.id } });
    if (!task) {
      return reply.code(404).send({ message: "タスクが見つかりません" });
    }

    return task;
  });

  // PUT /tasks/:id - 更新
  fastify.put("/tasks/:id", async (request, reply) => {
    const params = TaskIdParamSchema.parse(request.params);
    const parseResult = TaskInputSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.code(400).send({
        message: `バリデーションエラー: ${parseResult.error.issues
          .map((i) => i.message)
          .join(", ")}`,
      });
    }

    const exists = await prisma.task.findUnique({ where: { id: params.id } });
    if (!exists) {
      return reply.code(404).send({ message: "タスクが見つかりません" });
    }

    const task = await prisma.task.update({
      where: { id: params.id },
      data: parseResult.data,
    });

    return task;
  });

  // DELETE /tasks/:id - 削除
  fastify.delete("/tasks/:id", async (request, reply) => {
    const params = TaskIdParamSchema.parse(request.params);

    const exists = await prisma.task.findUnique({ where: { id: params.id } });
    if (!exists) {
      return reply.code(404).send({ message: "タスクが見つかりません" });
    }

    await prisma.task.delete({ where: { id: params.id } });
    return reply.code(204).send();
  });
}