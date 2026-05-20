# STEP04: task に picture_url 属性を追加

## 概要

Task モデルに画像の S3 キーを保存する `picture_key` フィールドを追加し、
API に画像アップロード URL 発行・Signed URL 付きレスポンスを実装する。

---

## 変更したファイル一覧

### 1. `app/prisma/schema.prisma`
`pictureKey` フィールドを追加（nullable）。
DB カラム名は `picture_key`（スネークケース）。

### 2. `app/prisma/migrations/`
マイグレーション SQL を追加：
```sql
ALTER TABLE "tasks" ADD COLUMN "picture_key" VARCHAR(500);
```

### 3. `app/package.json`
AWS SDK パッケージを追加：
| パッケージ | 用途 |
|---|---|
| `@aws-sdk/client-s3` | S3 操作 |
| `@aws-sdk/s3-request-presigner` | presigned URL 発行 |
| `@aws-sdk/client-secrets-manager` | 秘密鍵の取得 |
| `@aws-sdk/cloudfront-signer` | CloudFront Signed URL 発行 |

### 4. `app/src/lib/schemas.ts`
`TaskInputSchema` に `pictureKey` (optional string) を追加。

### 5. `app/src/lib/aws.ts`（新規）
- S3 クライアント初期化
- Secrets Manager から CF 秘密鍵を取得するヘルパー
- CloudFront Signed URL を発行するヘルパー

### 6. `app/src/routes/tasks.ts`
- `GET /tasks/:id` → `pictureKey` があれば `signedImageUrl` を付与して返す
- `GET /tasks` → 一覧でも同様に Signed URL を付与

### 7. `app/src/routes/images.ts`（新規）
- `GET /upload-url?filename=xxx.jpg` → S3 presigned PUT URL を発行

### 8. `app/src/server.ts`
- `imagesRoutes` を `/api` プレフィックスで登録

### 9. `infra/envs/dev/main.tf`
API ECS の `extra_environment` に画像関連の環境変数を追加：
- `S3_BUCKET_NAME`
- `CF_DOMAIN`
- `CF_KEY_PAIR_ID`
- `CF_PRIVATE_KEY_SECRET_ARN`

---

## API 仕様

### GET /api/upload-url
画像アップロード用 presigned URL を発行する。

**Query params:** `filename=xxx.jpg`

**Response:**
```json
{
  "uploadUrl": "https://s3.ap-northeast-1.amazonaws.com/...",
  "s3Key": "images/uuid.jpg"
}
```

### POST /api/tasks
`pictureKey` を含めてタスクを作成できる。

**Request body:**
```json
{
  "title": "タスク名",
  "pictureKey": "images/uuid.jpg"
}
```

### GET /api/tasks/:id
`pictureKey` がある場合、CloudFront Signed URL（有効期限 1 時間）を付与して返す。

**Response:**
```json
{
  "id": 1,
  "title": "タスク名",
  "pictureKey": "images/uuid.jpg",
  "signedImageUrl": "https://xxx.cloudfront.net/images/uuid.jpg?...",
  "createdAt": "...",
  "updatedAt": "..."
}
```

---

## マイグレーション手順（Bastion 経由）

```bash
# ターミナル1: SSM ポートフォワード
aws ssm start-session \
  --target <bastion_instance_id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<rds_endpoint>"],"portNumber":["5432"],"localPortNumber":["15432"]}' \
  --region ap-northeast-1

# ターミナル2: マイグレーション
cd task_api/app
npx prisma migrate deploy
```

---

## 次のステップ（STEP05）

フロントエンド（Next.js）の実装（タスク一覧・登録・画像アップロード UI）
