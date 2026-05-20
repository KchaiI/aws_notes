================================================================
STEP 04: バックエンド API - CSV エクスポートルート追加
================================================================

## 変更・作成ファイル
- task_api/app/src/routes/csv_exports.ts  （新規）
- task_api/app/src/lib/aws.ts             （SQS関連を追記）
- task_api/app/src/lib/env.ts             （環境変数追記）
- task_api/app/src/server.ts              （ルート登録追記）

---

## src/routes/csv_exports.ts

```typescript
import type { FastifyInstance } from "fastify";
import { prisma } from "../lib/prisma.js";
import { sendCsvExportMessage, generateCsvDownloadUrl } from "../lib/aws.js";

export async function csvExportsRoutes(fastify: FastifyInstance) {
  // POST /csv-exports - エクスポートジョブを作成
  fastify.post("/csv-exports", async (_request, reply) => {
    // ① RDS に pending レコード作成
    const csvExport = await prisma.csvExport.create({ data: {} });

    // ② SQS にメッセージ送信
    await sendCsvExportMessage(csvExport.id);

    return reply.code(201).send({
      id: csvExport.id,
      status: csvExport.status,
    });
  });

  // GET /csv-exports/:id - ステータス確認
  fastify.get<{ Params: { id: string } }>(
    "/csv-exports/:id",
    async (request, reply) => {
      const id = parseInt(request.params.id, 10);
      if (isNaN(id)) {
        return reply.code(400).send({ message: "IDが不正です" });
      }

      const csvExport = await prisma.csvExport.findUnique({ where: { id } });
      if (!csvExport) {
        return reply.code(404).send({ message: "エクスポートが見つかりません" });
      }

      // complete の場合は署名付きダウンロードURLを生成
      const downloadUrl =
        csvExport.status === "complete" && csvExport.s3Key
          ? await generateCsvDownloadUrl(csvExport.s3Key)
          : null;

      return {
        id: csvExport.id,
        status: csvExport.status,
        downloadUrl,
      };
    }
  );
}
```

---

## src/lib/aws.ts への追記

```typescript
import {
  SQSClient,
  SendMessageCommand,
  GetObjectCommand,
} from "@aws-sdk/client-sqs";
import { getSignedUrl as getS3SignedUrl } from "@aws-sdk/s3-request-presigner";

const sqs = new SQSClient({ region });

export async function sendCsvExportMessage(exportId: number): Promise<void> {
  const queueUrl = process.env.SQS_CSV_QUEUE_URL;
  if (!queueUrl) throw new Error("SQS_CSV_QUEUE_URL is not set");

  await sqs.send(
    new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify({ exportId }),
    })
  );
}

export async function generateCsvDownloadUrl(s3Key: string): Promise<string> {
  const bucket = process.env.S3_CSV_BUCKET_NAME;
  if (!bucket) throw new Error("S3_CSV_BUCKET_NAME is not set");

  const command = new GetObjectCommand({ Bucket: bucket, Key: s3Key });
  return getS3SignedUrl(s3, command, { expiresIn: 600 }); // 10分
}
```

---

## src/server.ts への追記

```typescript
import { csvExportsRoutes } from "./routes/csv_exports.js";

// 既存の登録に追加
await app.register(csvExportsRoutes, { prefix: "/api" });
```

---

## 追加する環境変数

| 変数名               | 内容                          |
|----------------------|-------------------------------|
| SQS_CSV_QUEUE_URL    | SQSキューのURL                |
| S3_CSV_BUCKET_NAME   | CSV出力用S3バケット名         |

---

## API レスポンス仕様

### POST /api/csv-exports

```json
// 201 Created
{
  "id": 1,
  "status": "pending"
}
```

### GET /api/csv-exports/:id

```json
// pending の場合
{
  "id": 1,
  "status": "pending",
  "downloadUrl": null
}

// complete の場合
{
  "id": 1,
  "status": "complete",
  "downloadUrl": "https://s3.ap-northeast-1.amazonaws.com/..."
}

// failed の場合
{
  "id": 1,
  "status": "failed",
  "downloadUrl": null
}
```
