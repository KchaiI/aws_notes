import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import { getSignedUrl as getCFSignedUrl } from "@aws-sdk/cloudfront-signer";
import { randomUUID } from "crypto";

const region = process.env.AWS_REGION ?? "ap-northeast-1";
const s3 = new S3Client({ region });
const sqs = new SQSClient({ region });
const secretsManager = new SecretsManagerClient({ region });

let cachedPrivateKey: string | null = null;

async function getCFPrivateKey(): Promise<string> {
  if (cachedPrivateKey) return cachedPrivateKey;

  const secretArn = process.env.CF_PRIVATE_KEY_SECRET_ARN;
  if (!secretArn) throw new Error("CF_PRIVATE_KEY_SECRET_ARN is not set");

  const res = await secretsManager.send(
    new GetSecretValueCommand({ SecretId: secretArn })
  );

  if (!res.SecretString) throw new Error("Secret has no string value");
  cachedPrivateKey = res.SecretString;
  return cachedPrivateKey;
}

export async function generateUploadUrl(filename: string): Promise<{ uploadUrl: string; s3Key: string }> {
  const bucket = process.env.S3_BUCKET_NAME;
  if (!bucket) throw new Error("S3_BUCKET_NAME is not set");

  const ext = filename.split(".").pop() ?? "jpg";
  const s3Key = `images/${randomUUID()}.${ext}`;

  const command = new PutObjectCommand({ Bucket: bucket, Key: s3Key });
  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

  return { uploadUrl, s3Key };
}

export async function generateSignedImageUrl(s3Key: string): Promise<string> {
  const domain = process.env.CF_DOMAIN;
  const keyPairId = process.env.CF_KEY_PAIR_ID;
  if (!domain || !keyPairId) throw new Error("CF_DOMAIN or CF_KEY_PAIR_ID is not set");

  const privateKey = await getCFPrivateKey();
  const url = `https://${domain}/${s3Key}`;
  const dateLessThan = new Date(Date.now() + 60 * 60 * 1000).toISOString();

  return getCFSignedUrl({ url, keyPairId, privateKey, dateLessThan });
}

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
  return getSignedUrl(s3, command, { expiresIn: 600 });
}
