import { useState, useEffect, useCallback } from 'react'
import { Plus, ClipboardList } from 'lucide-react'
import type { Task, TaskFormData, TaskStatus } from './types'
import { TaskCard } from './components/TaskCard'
import { TaskModal } from './components/TaskModal'
import { Toast } from './components/Toast'
import type { ToastMessage } from './components/Toast'

const BASE = '/api'

type FilterStatus = 'all' | TaskStatus

const FILTERS: { value: FilterStatus; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'pending', label: 'Pending' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'done', label: 'Done' },
]

export default function App() {
  const [tasks, setTasks] = useState<Task[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<FilterStatus>('all')
  const [showModal, setShowModal] = useState(false)
  const [editingTask, setEditingTask] = useState<Task | null>(null)
  const [toasts, setToasts] = useState<ToastMessage[]>([])

  const addToast = (type: 'success' | 'error', message: string) => {
    setToasts((prev) => [...prev, { id: Date.now(), type, message }])
  }

  const fetchTasks = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${BASE}/tasks`)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      setTasks(await res.json())
    } catch {
      addToast('error', 'タスクの取得に失敗しました')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { fetchTasks() }, [fetchTasks])

  const handleSave = async (data: TaskFormData) => {
    try {
      if (editingTask) {
        const res = await fetch(`${BASE}/tasks/${editingTask.id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data),
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const updated: Task = await res.json()
        setTasks((prev) => prev.map((t) => t.id === updated.id ? updated : t))
        addToast('success', 'タスクを更新しました')
      } else {
        const res = await fetch(`${BASE}/tasks`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data),
        })
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const created: Task = await res.json()
        setTasks((prev) => [created, ...prev])
        addToast('success', 'タスクを作成しました')
      }
    } catch (err) {
      addToast('error', 'タスクの保存に失敗しました')
      throw err
    }
  }

  const handleDelete = async (id: number) => {
    if (!window.confirm('このタスクを削除しますか？')) return
    try {
      const res = await fetch(`${BASE}/tasks/${id}`, { method: 'DELETE' })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      setTasks((prev) => prev.filter((t) => t.id !== id))
      addToast('success', 'タスクを削除しました')
    } catch {
      addToast('error', 'タスクの削除に失敗しました')
    }
  }

  const handleStatusChange = async (id: number, status: TaskStatus) => {
    const task = tasks.find((t) => t.id === id)
    if (!task) return
    try {
      const res = await fetch(`${BASE}/tasks/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: task.title, description: task.description ?? '', status }),
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const updated: Task = await res.json()
      setTasks((prev) => prev.map((t) => t.id === updated.id ? updated : t))
    } catch {
      addToast('error', 'ステータスの更新に失敗しました')
    }
  }

  const openCreate = () => { setEditingTask(null); setShowModal(true) }
  const openEdit = (task: Task) => { setEditingTask(task); setShowModal(true) }
  const closeModal = () => { setShowModal(false); setEditingTask(null) }

  const filtered = filter === 'all' ? tasks : tasks.filter((t) => t.status === filter)

  const counts: Record<FilterStatus, number> = {
    all: tasks.length,
    pending: tasks.filter((t) => t.status === 'pending').length,
    in_progress: tasks.filter((t) => t.status === 'in_progress').length,
    done: tasks.filter((t) => t.status === 'done').length,
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-100 sticky top-0 z-30">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <ClipboardList className="w-5 h-5 text-indigo-600" />
            <h1 className="text-lg font-bold text-gray-900">Task Manager</h1>
          </div>
          <button
            onClick={openCreate}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 active:bg-indigo-800 transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span className="hidden sm:inline">新規作成</span>
            <span className="sm:hidden">追加</span>
          </button>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 sm:px-6 py-6">
        {/* Filter tabs */}
        <div className="flex gap-1 mb-6 bg-white rounded-xl border border-gray-100 p-1 overflow-x-auto">
          {FILTERS.map((f) => (
            <button
              key={f.value}
              onClick={() => setFilter(f.value)}
              className={`flex items-center gap-1.5 px-3 sm:px-4 py-2 rounded-lg text-sm font-medium transition-colors flex-1 justify-center whitespace-nowrap ${
                filter === f.value
                  ? 'bg-indigo-600 text-white'
                  : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
              }`}
            >
              {f.label}
              <span
                className={`text-xs px-1.5 py-0.5 rounded-full font-semibold ${
                  filter === f.value
                    ? 'bg-indigo-500 text-white'
                    : 'bg-gray-100 text-gray-500'
                }`}
              >
                {counts[f.value]}
              </span>
            </button>
          ))}
        </div>

        {/* Content */}
        {loading ? (
          <div className="flex items-center justify-center py-32">
            <div className="w-7 h-7 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-32 text-center">
            <div className="w-14 h-14 bg-gray-100 rounded-2xl flex items-center justify-center mb-4">
              <ClipboardList className="w-7 h-7 text-gray-400" />
            </div>
            <p className="text-sm font-medium text-gray-500">タスクがありません</p>
            <p className="text-xs text-gray-400 mt-1">
              {filter === 'all'
                ? '「新規作成」でタスクを追加しましょう'
                : 'このステータスのタスクはありません'}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {filtered.map((task) => (
              <TaskCard
                key={task.id}
                task={task}
                onEdit={openEdit}
                onDelete={handleDelete}
                onStatusChange={handleStatusChange}
              />
            ))}
          </div>
        )}
      </main>

      {showModal && (
        <TaskModal
          task={editingTask}
          onSave={handleSave}
          onClose={closeModal}
        />
      )}

      <Toast
        toasts={toasts}
        onDismiss={(id) => setToasts((prev) => prev.filter((t) => t.id !== id))}
      />
    </div>
  )
}
