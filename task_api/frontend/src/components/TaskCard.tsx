import { Pencil, Trash2, Calendar } from 'lucide-react'
import type { Task, TaskStatus } from '../types'

type Props = {
  task: Task
  onEdit: (task: Task) => void
  onDelete: (id: number) => void
  onStatusChange: (id: number, status: TaskStatus) => void
}

const ALL_STATUSES: TaskStatus[] = ['pending', 'in_progress', 'done']

const STATUS_STYLES: Record<TaskStatus, string> = {
  pending: 'bg-gray-100 text-gray-600',
  in_progress: 'bg-blue-100 text-blue-600',
  done: 'bg-green-100 text-green-600',
}

const STATUS_LABELS: Record<TaskStatus, string> = {
  pending: 'Pending',
  in_progress: 'In Progress',
  done: 'Done',
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString('ja-JP', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

export function TaskCard({ task, onEdit, onDelete, onStatusChange }: Props) {
  return (
    <div className="bg-white rounded-xl border border-gray-100 p-5 hover:shadow-md hover:border-gray-200 transition-all flex flex-col gap-3">
      {/* Title row */}
      <div className="flex items-start justify-between gap-2">
        <h3 className="text-sm font-semibold text-gray-900 leading-snug break-words flex-1">
          {task.title}
        </h3>
        <div className="flex items-center gap-1 shrink-0">
          <button
            onClick={() => onEdit(task)}
            title="編集"
            className="p-1.5 text-gray-300 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
          >
            <Pencil className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => onDelete(task.id)}
            title="削除"
            className="p-1.5 text-gray-300 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Image */}
      {task.signedImageUrl && (
        <div className="rounded-lg overflow-hidden bg-gray-50 h-36">
          <img
            src={task.signedImageUrl}
            alt="task"
            className="w-full h-full object-cover"
          />
        </div>
      )}

      {/* Description */}
      {task.description && (
        <p className="text-xs text-gray-500 line-clamp-2 leading-relaxed">
          {task.description}
        </p>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between gap-2 mt-auto pt-1">
        <select
          value={task.status}
          onChange={(e) => onStatusChange(task.id, e.target.value as TaskStatus)}
          aria-label="ステータスを変更"
          className={`text-xs font-medium rounded-full px-2.5 py-1 cursor-pointer border-0 focus:outline-none focus:ring-2 focus:ring-indigo-300 transition-colors ${STATUS_STYLES[task.status]}`}
        >
          {ALL_STATUSES.map((s) => (
            <option key={s} value={s}>{STATUS_LABELS[s]}</option>
          ))}
        </select>

        <div className="flex items-center gap-1 text-xs text-gray-400">
          <Calendar className="w-3 h-3" />
          <span>{formatDate(task.createdAt)}</span>
        </div>
      </div>
    </div>
  )
}
