# STEP02: ECS 間通信（内部 ALB）

## 概要

フロントエンド ECS（Next.js）から API ECS（Fastify）へのサーバーサイド通信を、
VPC 内部に閉じた **Internal ALB** 経由で実現する。

---

## アーキテクチャ

```
【クライアントからのアクセス】
Browser → CloudFront → Public ALB
                         ├── /api/*   → API ECS
                         └── /*       → Frontend ECS

【フロントエンド SSR からの API 呼び出し】
Frontend ECS (SSR)
  │ INTERNAL_API_URL=http://internal-alb-dns
  ↓
Internal ALB (VPC 内部のみ・インターネット非公開)
  ↓
API ECS
```

### なぜ Internal ALB を使うのか

| 方法 | メリット | デメリット |
|---|---|---|
| **Internal ALB（本実装）** | VPC 内で完結・セキュア・ヘルスチェック管理 | ALB のコストが増える |
| Public ALB 経由 | 追加コスト不要 | フロントからの通信がインターネットを経由する |
| App Mesh | 高度なトラフィック制御 | 学習コストが高い |

---

## 変更したファイル一覧

### 1. `infra/modules/internal_alb/` （新規モジュール）

**main.tf**
- Internal ALB 本体（`internal = true`）
- セキュリティグループ（フロントエンド ECS SG からのポート 80 を許可）
- ターゲットグループ（API ECS 向け、ヘルスチェックパス `/health`）
- リスナー（ポート 80 → API ターゲットグループ）

**variables.tf**
| 変数 | 説明 |
|---|---|
| `allowed_security_group_ids` | アクセスを許可する SG のリスト（フロントエンド ECS SG を渡す）|
| `app_subnet_ids` | Internal ALB を配置するプライベートサブネット |
| `api_port` | API コンテナのポート（デフォルト 3000）|

**outputs.tf**
| 出力 | 用途 |
|---|---|
| `dns_name` | フロントエンドの環境変数 `INTERNAL_API_URL` に設定 |
| `security_group_id` | API ECS SG の追加許可ルールに使用 |
| `target_group_arn` | API ECS サービスの load_balancer ブロックに登録 |

---

### 2. `infra/modules/ecs/variables.tf`

| 追加変数 | デフォルト | 説明 |
|---|---|---|
| `additional_ingress_sg_ids` | `[]` | 追加で許可する SG ID リスト（Internal ALB SG など）|
| `extra_environment` | `[]` | 追加の環境変数（INTERNAL_API_URL など）|
| `register_to_internal_alb` | `false` | Internal ALB への登録フラグ |
| `internal_alb_target_group_arn` | `null` | Internal ALB のターゲットグループ ARN |

---

### 3. `infra/modules/ecs/main.tf`

#### セキュリティグループのインバウンドルールを動的に生成
```hcl
dynamic "ingress" {
  for_each = concat([var.alb_security_group_id], var.additional_ingress_sg_ids)
  content {
    from_port       = var.container_port
    security_groups = [ingress.value]
  }
}
```
API ECS SG は Public ALB SG に加えて Internal ALB SG からも受け付ける。

#### ECS サービスの load_balancer を動的に追加
```hcl
dynamic "load_balancer" {
  for_each = var.register_to_internal_alb ? ["internal"] : []
  content {
    target_group_arn = var.internal_alb_target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }
}
```
API ECS は Public ALB と Internal ALB の両方のターゲットグループに登録される。

#### extra_environment の追加
```hcl
environment = concat(
  [...base vars...],
  var.enable_db ? [...db vars...] : [],
  var.extra_environment   ← フロントエンドの INTERNAL_API_URL などを渡す
)
```

---

### 4. `infra/envs/dev/main.tf`

```hcl
module "internal_alb" {
  source = "../../modules/internal_alb"
  allowed_security_group_ids = [module.ecs_frontend.security_group_id]
}

# API ECS: Internal ALB にも登録
module "ecs" {
  additional_ingress_sg_ids    = [module.internal_alb.security_group_id]
  register_to_internal_alb     = true
  internal_alb_target_group_arn = module.internal_alb.target_group_arn
}

# Frontend ECS: Internal ALB の DNS を環境変数として渡す
module "ecs_frontend" {
  extra_environment = [
    { name = "INTERNAL_API_URL", value = "http://${module.internal_alb.dns_name}" }
  ]
}
```

---

## 新規作成されるリソース

| リソース名 | 種別 |
|---|---|
| `task-api-dev-internal-alb-sg` | Internal ALB 用 SG |
| `task-api-dev-internal-alb` | Internal ALB 本体 |
| `task-api-dev-internal-api-tg` | Internal ALB 用 API ターゲットグループ |
| Internal ALB リスナー（ポート 80）| ALB リスナー |

---

## 次のステップ（STEP03）

S3 バケット（暗号化）+ CloudFront の設定（画像保存・配信基盤の構築）

---

## terraform 適用手順

```bash
cd task_api/infra/envs/dev
terraform init
terraform plan
terraform apply
```
