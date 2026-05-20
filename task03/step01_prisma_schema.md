================================================================
STEP 01: Prisma Schema に CsvExport モデルを追加
================================================================

## 変更ファイル
- task_api/app/prisma/schema.prisma
- task_api/app/prisma/migrations/YYYYMMDD_add_csv_exports/migration.sql

---

## schema.prisma に追加する内容

```prisma
enum CsvExportStatus {
  pending
  complete
  failed

  @@map("csv_export_status")
}

model CsvExport {
  id        Int             @id @default(autoincrement())
  status    CsvExportStatus @default(pending)
  s3Key     String?         @db.VarChar(500) @map("s3_key")
  createdAt DateTime        @default(now()) @map("created_at")
  updatedAt DateTime        @updatedAt @map("updated_at")

  @@map("csv_exports")
}
```

---

## migration SQL（自動生成されるが内容の確認用）

```sql
CREATE TYPE "csv_export_status" AS ENUM ('pending', 'complete', 'failed');

CREATE TABLE "csv_exports" (
    "id"         SERIAL NOT NULL,
    "status"     "csv_export_status" NOT NULL DEFAULT 'pending',
    "s3_key"     VARCHAR(500),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "csv_exports_pkey" PRIMARY KEY ("id")
);
```

---

## 実行コマンド

```bash
cd task_api/app

# 1. スキーマ編集後にmigrationファイルを生成（本番DBには適用しない）
npx prisma migrate dev --name add_csv_exports

# または本番向けにSQLだけ生成する場合
npx prisma migrate diff \
  --from-schema-datasource prisma/schema.prisma \
  --to-schema-datamodel prisma/schema.prisma \
  --script
```

---

## ポイント

- `s3Key` は nullable: pending/failed 状態では null、complete になった時点でS3キーを設定する
- `status` は enum で型安全に管理する
- 既存の `Task` モデルとは独立したテーブル（リレーションなし）
