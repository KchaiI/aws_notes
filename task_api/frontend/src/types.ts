export type TaskStatus = 'pending' | 'in_progress' | 'done'

export type Task = {
  id: number
  title: string
  description: string | null
  status: TaskStatus
  createdAt: string
  updatedAt: string
}

export type TaskFormData = {
  title: string
  description: string
  status: TaskStatus
}
