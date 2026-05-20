================================================================
課題03: CSV出力機能の追加（非同期処理 + SQS + Worker）
================================================================

## 概要

タスク一覧をCSVとしてエクスポートする機能を実装する。
処理の流れは以下の通り：

  フロントエンド → API → RDS(pending) → SQS → Worker → S3 + RDS(complete)

CSVの生成はAPIサーバーでは行わず、SQSを経由してWorkerサーバーに委譲する。
これにより、APIサーバーをブロックせず、大量データでも安全に処理できる。

---

## アーキテクチャ図

```
[フロントエンド (ECS)]
  CSVエクスポートボタン
       ↓ POST /api/csv-exports
[API サーバー (ECS)]
  ① RDS に csv_exports レコード作成 (status: pending)
  ② SQS にメッセージ送信 { exportId: 1 }
  ③ { id: 1, status: "pending" } を返す
       ↓ SQS メッセージ
[Worker サーバー (ECS - 新規)]
  ④ SQS をロングポーリング
  ⑤ RDS から全タスクを取得
  ⑥ CSV を生成 → S3 にアップロード
  ⑦ RDS の csv_exports を complete + s3_key 更新
       ↑ フロントエンドがポーリング
[フロントエンド]
  GET /api/csv-exports/:id でステータス確認
  complete になったら署名付きURLでCSVダウンロード
```

---

## なぜこの設計か

| 課題                         | 解決策                                   |
|------------------------------|------------------------------------------|
| CSV生成は時間がかかる         | 非同期処理にして即座にレスポンスを返す    |
| APIサーバーをブロックしたくない | Workerを別ECSサービスに分離              |
| 処理の確実な実行              | SQSのメッセージ保持・再試行機能を利用     |
| 生成済みCSVの安全な配信       | S3に格納し署名付きURLで配信              |

---

## 処理フロー詳細

```
フロント              API サーバー         SQS          Worker
  |                        |                |               |
  |-- POST /csv-exports --> |                |               |
  |                        |-- INSERT --> RDS(pending)       |
  |                        |-- SendMessage ->|               |
  |<-- { id:1, pending }  --|                |               |
  |                        |                |-- Receive --> |
  |                        |                |               |-- SELECT tasks
  |                        |                |               |-- CSV生成
  |                        |                |               |-- S3 PutObject
  |                        |                |               |-- UPDATE complete
  |                        |                |<-- Delete  ---|
  |-- GET /csv-exports/1 ->|                |               |
  |                        |-- SELECT --> RDS               |
  |<-- { complete, url } --|                |               |
  |-- ファイルDL ----------|                |               |
```

---

## 実装するコンポーネント一覧

### 1. RDS スキーマ変更（Prisma）

新テーブル `csv_exports` を追加：

```
id         Int       (PK, autoincrement)
status     Enum      (pending | complete | failed)
s3Key      String?   (complete時に設定されるS3キー)
createdAt  DateTime
updatedAt  DateTime
```

ファイル: `task_api/app/prisma/schema.prisma`
Migration: `task_api/app/prisma/migrations/YYYYMMDD_add_csv_exports/`

### 2. バックエンド API（既存ECSに追加）

新規ルート `task_api/app/src/routes/csv_exports.ts`：

- `POST /csv-exports`
  - RDS に pending レコード作成
  - SQS に `{ exportId }` を送信
  - `{ id, status: "pending" }` を返す

- `GET /csv-exports/:id`
  - RDS からステータス確認
  - complete なら S3署名付きURLを生成して返す
  - `{ id, status, downloadUrl? }` を返す

### 3. SQS キュー（Terraform 新規モジュール）

ファイル: `task_api/infra/modules/sqs/`

- Standard Queue（順序保証不要、シンプル）
- visibility timeout: 300秒（Worker処理時間の目安）
- message retention: 4日（デフォルト）

### 4. CSV出力用 S3 バケット（Terraform 新規モジュール）

ファイル: `task_api/infra/modules/s3_csv/`

- 画像用S3（s3_images）とは別バケット
- 署名付きURL（Presigned URL）で配信（CloudFrontは不要）
- バケットポリシー: パブリックアクセス禁止

### 5. Worker サーバー（新規 ECS サービス）

ファイル: `task_api/worker/`

```
worker/
  src/
    worker.ts       # SQSポーリングのメインループ
    lib/
      prisma.ts     # DB接続（APIと共通のスキーマ）
      csv.ts        # CSV生成ロジック
      aws.ts        # SQS受信・削除、S3アップロード
      env.ts        # 環境変数
  Dockerfile
  package.json
  tsconfig.json
```

処理の流れ：
1. SQS をロングポーリング（WaitTimeSeconds: 20）
2. メッセージから `exportId` を取得
3. RDS の全タスクを取得
4. CSV文字列を生成（BOM付きUTF-8でExcel対応）
5. S3 に `csv/{exportId}.csv` でアップロード
6. RDS の csv_exports を `complete` + `s3Key` で更新
7. SQSメッセージを削除

### 6. Terraform: Worker用インフラ

既存モジュール更新・追加：

- `modules/ecr/` : Worker用ECRリポジトリを追加
- `modules/ecs/` : Workerサービス追加（desired_count: 1）
- `modules/iam/` : SQS・S3のポリシーをAPIロール・Workerロールに追加
- `envs/dev/main.tf` : 新モジュールの呼び出し追加

### 7. フロントエンド

`task_api/frontend/src/App.tsx` に追加：

- CSVエクスポートボタン（ヘッダーに配置）
- `POST /csv-exports` を呼び出し
- 1秒ごとに `GET /csv-exports/:id` をポーリング
- `complete` になったらダウンロードURLを開く
- Toast でエクスポート中・完了・エラーを通知

---

## IAM 権限設計

### API サーバーの IAM ロールに追加
- `sqs:SendMessage` → CSV出力用SQSキュー

### Worker の IAM ロール（新規作成）
- `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` → CSV出力用SQSキュー
- `s3:PutObject` → CSV出力用S3バケット
- `rds-db:connect` → RDS（接続はDB URL経由なので不要な場合あり）

---

## 環境変数

### API サーバーに追加
```
SQS_CSV_QUEUE_URL   SQSキューのURL
```

### Worker（新規）
```
DATABASE_URL        RDSの接続文字列（APIと共通）
SQS_CSV_QUEUE_URL   SQSキューのURL
S3_CSV_BUCKET_NAME  CSV用S3バケット名
AWS_REGION          ap-northeast-1
```

---

## 実装順序

1. Prisma schema に CsvExport モデルを追加 → migration
2. Terraform: SQS モジュール作成
3. Terraform: CSV用S3バケット作成
4. バックエンド: POST/GET /csv-exports ルート実装
5. Worker アプリ実装（SQSポーリング + CSV生成 + S3アップロード）
6. Terraform: Worker用ECR + ECSサービス + IAM
7. フロントエンド: CSVエクスポートボタン + ポーリング

各ステップの詳細は step01〜step07 の個別ファイルを参照。
