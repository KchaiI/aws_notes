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

export async function receiveMessages(): Promise<Message[]> {
  const queueUrl = process.env.SQS_CSV_QUEUE_URL;
  if (!queueUrl) throw new Error("SQS_CSV_QUEUE_URL is not set");

  const res = await sqs.send(
    new ReceiveMessageCommand({
      QueueUrl: queueUrl,
      MaxNumberOfMessages: 1,
      WaitTimeSeconds: 20,
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
  const bucket = process.env.S3_CSV_BUCKET_NAME;
  if (!bucket) throw new Error("S3_CSV_BUCKET_NAME is not set");

  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: s3Key,
      Body: Buffer.from(csv, "utf-8"),
      ContentType: "text/csv; charset=utf-8",
      ContentDisposition: 'attachment; filename="tasks.csv"',
    })
  );
}
