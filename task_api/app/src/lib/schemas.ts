import { z } from "zod";

export const TaskStatusSchema = z.enum(["pending", "in_progress", "done"]);

export const TaskInputSchema = z.object({
  title: z.string().min(1).max(255),
  description: z.string().optional(),
  status: TaskStatusSchema.optional(),
});

export const TaskIdParamSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const TaskListQuerySchema = z.object({
  status: TaskStatusSchema.optional(),
});

export type TaskInput = z.infer<typeof TaskInputSchema>;
export type TaskIdParam = z.infer<typeof TaskIdParamSchema>;
export type TaskListQuery = z.infer<typeof TaskListQuerySchema>;