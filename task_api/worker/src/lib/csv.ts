import type { Task } from "@prisma/client";

export function generateCsv(tasks: Task[]): string {
  const headers = ["ID", "タイトル", "説明", "ステータス", "作成日時", "更新日時"];
  const rows = tasks.map((t) => [
    t.id,
    escapeCsvField(t.title),
    escapeCsvField(t.description ?? ""),
    t.status,
    t.createdAt.toISOString(),
    t.updatedAt.toISOString(),
  ]);

  const lines = [headers, ...rows].map((row) => row.join(","));

  // BOM付きUTF-8 (Excelで文字化けしないように)
  return "﻿" + lines.join("\r\n");
}

function escapeCsvField(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}
