================================================================
STEP 07: フロントエンド - CSV エクスポートボタンの追加
================================================================

## 変更ファイル
- task_api/frontend/src/App.tsx  （ボタン + ポーリング + ダウンロード処理を追加）

---

## 追加する処理の流れ

```
1. ユーザーが「CSVエクスポート」ボタンをクリック
2. POST /api/csv-exports → { id, status: "pending" } を受け取る
3. 1秒ごとに GET /api/csv-exports/:id をポーリング
4. status が "complete" になったら downloadUrl をブラウザで開く（自動DL）
5. ダウンロード完了のToastを表示
6. status が "failed" になったらエラーToastを表示
```

---

## App.tsx に追加するコード

### state・関数の追加

```tsx
const [csvExporting, setCsvExporting] = useState(false)

const handleCsvExport = async () => {
  setCsvExporting(true)
  addToast('success', 'CSVの生成を開始しました...')

  try {
    // ① エクスポートジョブ作成
    const res = await fetch(`${BASE}/csv-exports`, { method: 'POST' })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const { id } = await res.json()

    // ② ポーリング（最大60秒 / 1秒間隔）
    for (let i = 0; i < 60; i++) {
      await new Promise((r) => setTimeout(r, 1000))

      const statusRes = await fetch(`${BASE}/csv-exports/${id}`)
      if (!statusRes.ok) throw new Error(`HTTP ${statusRes.status}`)
      const data = await statusRes.json()

      if (data.status === 'complete' && data.downloadUrl) {
        // ③ ダウンロード
        const a = document.createElement('a')
        a.href = data.downloadUrl
        a.download = 'tasks.csv'
        a.click()
        addToast('success', 'CSVのダウンロードを開始しました')
        return
      }

      if (data.status === 'failed') {
        throw new Error('CSV生成に失敗しました')
      }
    }

    throw new Error('タイムアウト: CSV生成に時間がかかっています')
  } catch (err) {
    addToast('error', err instanceof Error ? err.message : 'CSV出力に失敗しました')
  } finally {
    setCsvExporting(false)
  }
}
```

---

### ヘッダーへのボタン追加

```tsx
import { Plus, ClipboardList, Download } from 'lucide-react'

// ヘッダー内の既存ボタンの隣に追加
<button
  onClick={handleCsvExport}
  disabled={csvExporting}
  className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-200 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-50 active:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
>
  <Download className="w-4 h-4" />
  <span className="hidden sm:inline">
    {csvExporting ? '生成中...' : 'CSVエクスポート'}
  </span>
</button>
```

---

## UIの配置イメージ

```
┌─────────────────────────────────────────────────┐
│  📋 Task Manager         [CSVエクスポート] [新規作成] │
└─────────────────────────────────────────────────┘
```

---

## Toast の表示タイミング

| タイミング              | Toast の内容                         |
|------------------------|--------------------------------------|
| ボタンクリック時        | "CSVの生成を開始しました..."          |
| complete & DL開始      | "CSVのダウンロードを開始しました"     |
| failed                 | "CSV生成に失敗しました"               |
| タイムアウト（60秒）   | "タイムアウト: CSV生成に時間がかかっています" |

---

## ポイント

- ボタンは処理中に `disabled` にしてダブルクリックを防止
- ポーリング間隔は1秒（ユーザー体験とAPI負荷のバランス）
- タイムアウトは60秒（通常は数秒で完了するが念のため上限を設ける）
- `document.createElement('a')` でプログラム的にダウンロードをトリガー
