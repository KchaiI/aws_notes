import { receiveMessages, deleteMessage, uploadCsv } from "./lib/aws.js";
import { prisma } from "./lib/prisma.js";
import { generateCsv } from "./lib/csv.js";

async function processMessage(body: string, receiptHandle: string): Promise<void> {
  const { exportId } = JSON.parse(body) as { exportId: number };
  console.log(`[worker] Processing exportId: ${exportId}`);

  try {
    const tasks = await prisma.task.findMany({ orderBy: { id: "asc" } });
    const csv = generateCsv(tasks);
    const s3Key = `csv/${exportId}.csv`;

    await uploadCsv(s3Key, csv);

    await prisma.csvExport.update({
      where: { id: exportId },
      data: { status: "complete", s3Key },
    });

    await deleteMessage(receiptHandle);
    console.log(`[worker] Completed exportId: ${exportId}`);
  } catch (err) {
    console.error(`[worker] Failed exportId: ${exportId}`, err);

    await prisma.csvExport.update({
      where: { id: exportId },
      data: { status: "failed" },
    }).catch(() => {});

    // メッセージは削除しない → visibility timeout 後に再試行
  }
}

async function main(): Promise<void> {
  console.log("[worker] Started");

  while (true) {
    const messages = await receiveMessages();
    for (const msg of messages) {
      if (msg.Body && msg.ReceiptHandle) {
        await processMessage(msg.Body, msg.ReceiptHandle);
      }
    }
  }
}

main().catch((err) => {
  console.error("[worker] Crashed:", err);
  process.exit(1);
});
