-- CreateEnum
CREATE TYPE "csv_export_status" AS ENUM ('pending', 'complete', 'failed');

-- CreateTable
CREATE TABLE "csv_exports" (
    "id" SERIAL NOT NULL,
    "status" "csv_export_status" NOT NULL DEFAULT 'pending',
    "s3_key" VARCHAR(500),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "csv_exports_pkey" PRIMARY KEY ("id")
);
