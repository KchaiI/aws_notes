# STEP05: フロントエンドデプロイ

## 概要
React + Vite で実装したフロントエンドを Docker イメージ化し、ECS Fargate にデプロイする。
CloudFront → ALB のパスベースルーティングにより、`/api/*` は API コンテナへ、それ以外はフロントエンドコンテナへ転送される。

## 実施内容

### 1. フロントエンドコード更新
画像アップロード機能を追加。

**types.ts**: `Task` 型に `pictureKey` / `signedImageUrl` を追加
```typescript
export type Task = {
  ...
  pictureKey: string | null
  signedImageUrl: string | null
}
export type TaskFormData = {
  ...
  pictureKey?: string
}
```

**TaskModal.tsx**: 画像アップロード UI を追加
- ファイル選択 → `GET /api/upload-url?filename=xxx` で S3 Presigned PUT URL を取得
- S3 に直接 PUT アップロード
- `s3Key` を `pictureKey` として保存
- アップロード中はボタンを無効化

**TaskCard.tsx**: `signedImageUrl` がある場合に画像サムネイルを表示

### 2. Dockerfile 作成（マルチステージビルド）
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
```

### 3. nginx.conf
```nginx
server {
    listen 3000;   # ECS の container_port に合わせる
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;  # SPA ルーティング対応
    }
}
```

### 4. Docker イメージビルド & ECR push
```bash
# Apple Silicon → ECS は linux/amd64 が必要
cd task_api/frontend
docker build --platform linux/amd64 -t task-api-dev-frontend .
docker tag task-api-dev-frontend:latest \
  058898200941.dkr.ecr.ap-northeast-1.amazonaws.com/task-api-dev-frontend:latest
docker push 058898200941.dkr.ecr.ap-northeast-1.amazonaws.com/task-api-dev-frontend:latest
```

### 5. ECS フロントエンドサービス起動
Terraform で `desired_count = 0` にしてあったサービスを 1 に変更。

```bash
aws ecs update-service \
  --cluster task-api-dev-cluster \
  --service task-api-dev-frontend-service \
  --desired-count 1 \
  --force-new-deployment \
  --region ap-northeast-1

aws ecs wait services-stable \
  --cluster task-api-dev-cluster \
  --services task-api-dev-frontend-service
```

## ALB パスルーティング構成
| パターン | 転送先 |
|---|---|
| `/api/*` | API ECS (port 3000) |
| `/health`, `/health/*` | API ECS (ヘルスチェック) |
| それ以外 (デフォルト) | フロントエンド ECS (port 3000) |

## 動作確認
```bash
BASE="http://task-api-dev-alb-359393790.ap-northeast-1.elb.amazonaws.com"
curl -s -o /dev/null -w "HTTP %{http_code}" "$BASE/"          # HTTP 200
curl -s -o /dev/null -w "HTTP %{http_code}" "$BASE/api/tasks" # HTTP 200
curl -s "$BASE/api/upload-url?filename=test.jpg"              # uploadUrl と s3Key が返る
```

## インフラ概要（復習）
- **Terraform module "ecs_frontend"**: `desired_count = 0` → `1` に更新
- **ECR**: `task-api-dev-frontend` リポジトリ
- **ECS cluster**: `task-api-dev-cluster`（API と共有）
- **ECS service**: `task-api-dev-frontend-service`
- **ALB**: `task-api-dev-alb`（フロントエンドがデフォルトTG）
