import { useEffect } from 'react'
import { X, CheckCircle, AlertCircle } from 'lucide-react'

export type ToastType = 'success' | 'error'

export type ToastMessage = {
  id: number
  type: ToastType
  message: string
}

type Props = {
  toasts: ToastMessage[]
  onDismiss: (id: number) => void
}

export function Toast({ toasts, onDismiss }: Props) {
  return (
    <div className="fixed top-4 right-4 z-50 flex flex-col gap-2 pointer-events-none">
      {toasts.map((t) => (
        <ToastItem key={t.id} toast={t} onDismiss={onDismiss} />
      ))}
    </div>
  )
}

function ToastItem({ toast, onDismiss }: { toast: ToastMessage; onDismiss: (id: number) => void }) {
  useEffect(() => {
    const timer = setTimeout(() => onDismiss(toast.id), 4000)
    return () => clearTimeout(timer)
  }, [toast.id, onDismiss])

  const isSuccess = toast.type === 'success'

  return (
    <div
      className={`pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg min-w-64 max-w-sm bg-white border animate-in slide-in-from-right-4 fade-in duration-200 ${
        isSuccess ? 'border-green-200' : 'border-red-200'
      }`}
    >
      {isSuccess ? (
        <CheckCircle className="w-4 h-4 text-green-500 shrink-0" />
      ) : (
        <AlertCircle className="w-4 h-4 text-red-500 shrink-0" />
      )}
      <p className="text-sm text-gray-700 flex-1">{toast.message}</p>
      <button
        onClick={() => onDismiss(toast.id)}
        className="text-gray-300 hover:text-gray-500 transition-colors"
      >
        <X className="w-3.5 h-3.5" />
      </button>
    </div>
  )
}
