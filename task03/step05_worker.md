================================================================
STEP 05: Worker サーバーの実装
================================================================

## 作成ファイル（新規ディレクトリ）

```
task_api/worker/
  src/
    worker.ts         # メインループ
    lib/
      prisma.ts       # DB接続
      csv.ts          # CSV生成
      aws.ts          # SQS・S3操作
      env.ts          # 環境変数
  Dockerfile
  package.json
  tsconfig.json
```

---

## src/worker.ts（メインループ）

```typescript
import { receiveMessage, deleteMessage, uploadCsv } from "./lib/aws.js";
import { prisma } from "./lib/prisma.js";
import { generateCsv } from "./lib/csv.js";

async function processMessage(body: string, receiptHandle: string) {
  const { exportId } = JSON.parse(body) as { exportId: number };
  console.log(`Processing exportId: ${exportId}`);

  try {
    // タスク全件取得
    const tasks = await prisma.task.findMany({ orderBy: { id: "asc" } });

    // CSV生成
    const csv = generateCsv(tasks);

    // S3アップロード
    const s3Key = `csv/${exportId}.csv`;
    await uploadCsv(s3Key, csv);

    // RDS を complete に更新
    await prisma.csvExport.update({
      where: { id: exportId },
      data: { status: "complete", s3Key },
    });

    // SQSメッセージ削除
    await deleteMessage(receiptHandle);
    console.log(`Completed exportId: ${exportId}`);
  } catch (err) {
    console.error(`Failed exportId: ${exportId}`, err);

    // RDS を failed に更新
    await prisma.csvExport.update({
      where: { id: exportId },
      data: { status: "failed" },
    }).catch(() => {});

    // SQSメッセージは削除しない → visibility timeout 後に再試行
  }
}

async function main() {
  console.log("Worker started");

  while (true) {
    const messages = await receiveMessage();

    for (const msg of messages) {
      if (msg.Body && msg.ReceiptHandle) {
        await processMessage(msg.Body, msg.ReceiptHandle);
      }
    }
  }
}

main().catch((err) => {
  console.error("Worker crashed:", err);
  process.exit(1);
});
```

---

## src/lib/csv.ts（CSV生成）

```typescript
import type { Task } from "@prisma/client";

export function generateCsv(tasks: Task[]): string {
  const headers = ["ID", "タイトル", "説明", "ステータス", "作成日時", "更新日時"];
  const rows = tasks.map((t) => [
    t.id,
    escapeCsvField(t.title),
    escapeCsvField(t.description ?? ""),
    t.status,
    t.createdAt.toISOString(),
    t.updatedAt.toISOString(),
  ]);

  const lines = [headers, ...rows].map((row) => row.join(","));

  // BOM付きUTF-8 (Excelで文字化けしないように)
  return "﻿" + lines.join("\r\n");
}

function escapeCsvField(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}
```

---

## src/lib/aws.ts（SQS・S3操作）

```typescript
import {
  SQSClient,
  ReceiveMessageCommand,
  DeleteMessageCommand,
  type Message,
} from "@aws-sdk/client-sqs";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const region = process.env.AWS_REGION ?? "ap-northeast-1";
const sqs = new SQSClient({ region });
const s3 = new S3Client({ region });

export async function receiveMessage(): Promise<Message[]> {
  const queueUrl = process.env.SQS_CSV_QUEUE_URL!;
  const res = await sqs.send(
    new ReceiveMessageCommand({
      QueueUrl: queueUrl,
      MaxNumberOfMessages: 1,
      WaitTimeSeconds: 20, // ロングポーリング
    })
  );
  return res.Messages ?? [];
}

export async function deleteMessage(receiptHandle: string): Promise<void> {
  const queueUrl = process.env.SQS_CSV_QUEUE_URL!;
  await sqs.send(
    new DeleteMessageCommand({ QueueUrl: queueUrl, ReceiptHandle: receiptHandle })
  );
}

export async function uploadCsv(s3Key: string, csv: string): Promise<void> {
  const bucket = process.env.S3_CSV_BUCKET_NAME!;
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: s3Key,
      Body: Buffer.from(csv, "utf-8"),
      ContentType: "text/csv; charset=utf-8",
      ContentDisposition: `attachment; filename="tasks.csv"`,
    })
  );
}
```

---

## Dockerfile

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

CMD ["node", "dist/worker.js"]
```

---

## package.json（主要部分）

```json
{
  "name": "task-worker",
  "scripts": {
    "build": "tsc",
    "start": "node dist/worker.js"
  },
  "dependencies": {
    "@aws-sdk/client-sqs": "^3.x",
    "@aws-sdk/client-s3": "^3.x",
    "@prisma/client": "^6.x"
  },
  "devDependencies": {
    "typescript": "^5.x",
    "prisma": "^6.x"
  }
}
```

---

## ポイント

- `WaitTimeSeconds: 20` のロングポーリングでコスト削減（短ポーリングは無駄なリクエストが多い）
- エラー時はSQSメッセージを削除しない → visibility timeout 後にWorkerが再試行する
- BOM付きUTF-8でExcelでも文字化けしない
- Workerは1つのECSタスクとして常時起動（オートスケーリングは今回省略）
