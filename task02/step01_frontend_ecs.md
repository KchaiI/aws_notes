# STEP01: フロントエンド ECS の追加

## 概要

既存の API 用 ECS に加えて、フロントエンド（Next.js / React）用の ECS サービスを追加した。
ALB のパスベースルーティングで API とフロントエンドを振り分ける構成にした。

---

## アーキテクチャ

```
Internet
  │
CloudFront
  │
ALB (Public)
  ├── /api/*  → API ECS (Fastify)         ← 既存
  ├── /health → API ECS (Fastify)         ← 既存
  └── /*      → Frontend ECS (Next.js)    ← 新規追加
```

---

## 変更したファイル一覧

### 1. `infra/modules/ecs/variables.tf`

以下の変数を追加・変更した。

| 変数 | 変更内容 |
|---|---|
| `db_secret_arn` | `default = null` を追加（フロントエンドは DB 不要）|
| `db_endpoint` | `default = null` を追加 |
| `db_name` | `default = null` を追加 |
| `cluster_arn` | 新規追加。既存クラスターを再利用する場合に渡す |
| `name_suffix` | 新規追加。同一クラスター内で複数サービスを区別するためのサフィックス |

### 2. `infra/modules/ecs/main.tf`

#### locals の変更
- `name_suffix` が空でない場合は `${project}-${environment}-${name_suffix}` を name_prefix として使用
- `cluster_arn` を local 変数として定義し、既存クラスター再利用 or 新規作成を自動判定

#### クラスター作成の条件化
```hcl
resource "aws_ecs_cluster" "this" {
  count = var.cluster_arn == null ? 1 : 0
  ...
}
```
`cluster_arn` が指定された場合はクラスターを新規作成しない。

#### Secrets Manager IAM ポリシーの条件化
```hcl
resource "aws_iam_role_policy" "task_execution_secrets" {
  count = var.db_secret_arn != null ? 1 : 0
  ...
}
```
DB が不要なフロントエンドでは Secrets Manager への権限を付与しない。

#### コンテナ定義の条件化
- `environment`: DB 関連の環境変数（DB_HOST, DB_PORT, DB_NAME）を `db_endpoint != null` の場合のみ設定
- `secrets`: DB_USER, DB_PASSWORD を `db_secret_arn != null` の場合のみ設定

### 3. `infra/modules/ecs/outputs.tf`

- `cluster_name`: 条件化（新規作成時のみクラスター名を返す）
- `cluster_arn`: `local.cluster_arn` を参照するよう変更

### 4. `infra/modules/alb/variables.tf`

以下の変数を追加した。

| 変数 | デフォルト値 | 説明 |
|---|---|---|
| `frontend_port` | `3000` | フロントエンドコンテナのポート番号 |
| `frontend_health_check_path` | `/` | フロントエンドのヘルスチェックパス |

### 5. `infra/modules/alb/main.tf`

#### フロントエンド用ターゲットグループを追加
```hcl
resource "aws_lb_target_group" "frontend" {
  name = "${local.name_prefix}-frontend-tg"
  port = var.frontend_port
  ...
}
```

#### リスナーのデフォルト転送先をフロントエンドに変更
```
変更前: デフォルト → API ターゲットグループ
変更後: デフォルト → フロントエンドターゲットグループ
```

#### API 用リスナールールを追加
```hcl
resource "aws_lb_listener_rule" "api" {
  priority = 10
  condition {
    path_pattern {
      values = ["/api/*", "/health", "/health/*"]
    }
  }
  action { target_group_arn = aws_lb_target_group.this.arn }
}
```
`/api/*` と `/health*` へのリクエストは API ECS に転送する。

### 6. `infra/modules/alb/outputs.tf`

- `frontend_target_group_arn` を追加（フロントエンド ECS サービスが登録対象として使う）

### 7. `infra/envs/dev/main.tf`

フロントエンド用の ECR・ECS モジュールを追加した。

```hcl
module "ecr_frontend" {
  source          = "../../modules/ecr"
  repository_name = "frontend"
}

module "ecs_frontend" {
  source        = "../../modules/ecs"
  name_suffix   = "frontend"
  cluster_arn   = module.ecs.cluster_arn  # API と同じクラスターを共有
  desired_count = 0                        # アプリ未完成のため初期は 0
  ...
}
```

---

## 新規作成されるリソース

| リソース名 | 種別 |
|---|---|
| `task-api-dev-frontend` (ECR) | フロントエンド用コンテナイメージの保存先 |
| `task-api-dev-frontend-tg` (ALB TG) | フロントエンド用ターゲットグループ |
| `task-api-dev-api-rule` (ALB Rule) | `/api/*` → API へのルーティングルール |
| `task-api-dev-frontend-ecs-task-sg` | フロントエンドタスク用セキュリティグループ |
| `/ecs/task-api-dev-frontend` (CW Logs) | フロントエンドのログ出力先 |
| `task-api-dev-frontend-task` (ECS Task) | フロントエンド用タスク定義 |
| `task-api-dev-frontend-service` (ECS) | フロントエンド用 ECS サービス（初期 desired=0）|

---

## 次のステップ（STEP02）

ECS 間通信の設計・実装（内部 ALB を使ってフロントエンドから API へアクセスする）

---

## terraform 適用手順

```bash
cd task_api/infra/envs/dev

# 新しいモジュールを初期化
terraform init

# 変更内容を確認
terraform plan

# 適用
terraform apply
```
