import type { FastifyInstance } from "fastify";
import { prisma } from "../lib/prisma.js";
import { sendCsvExportMessage, generateCsvDownloadUrl } from "../lib/aws.js";

export async function csvExportsRoutes(fastify: FastifyInstance) {
  fastify.post("/csv-exports", async (_request, reply) => {
    const csvExport = await prisma.csvExport.create({ data: {} });
    await sendCsvExportMessage(csvExport.id);
    return reply.code(201).send({ id: csvExport.id, status: csvExport.status });
  });

  fastify.get<{ Params: { id: string } }>("/csv-exports/:id", async (request, reply) => {
    const id = parseInt(request.params.id, 10);
    if (isNaN(id)) {
      return reply.code(400).send({ message: "IDが不正です" });
    }

    const csvExport = await prisma.csvExport.findUnique({ where: { id } });
    if (!csvExport) {
      return reply.code(404).send({ message: "エクスポートが見つかりません" });
    }

    const downloadUrl =
      csvExport.status === "complete" && csvExport.s3Key
        ? await generateCsvDownloadUrl(csvExport.s3Key)
        : null;

    return { id: csvExport.id, status: csvExport.status, downloadUrl };
  });
}
