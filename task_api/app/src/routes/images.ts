import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { generateUploadUrl } from "../lib/aws.js";

const UploadUrlQuerySchema = z.object({
  filename: z.string().min(1).max(255),
});

export async function imagesRoutes(fastify: FastifyInstance) {
  // GET /upload-url?filename=xxx.jpg - S3 presigned PUT URL を発行
  fastify.get("/upload-url", async (request, reply) => {
    const parseResult = UploadUrlQuerySchema.safeParse(request.query);
    if (!parseResult.success) {
      return reply.code(400).send({ message: "filename は必須です" });
    }

    const { uploadUrl, s3Key } = await generateUploadUrl(parseResult.data.filename);
    return { uploadUrl, s3Key };
  });
}
