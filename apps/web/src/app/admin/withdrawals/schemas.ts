import { z } from "zod";

export const idsSchema = z.array(z.uuid()).min(1).max(50);
export const transferRefSchema = z.string().trim().regex(/^[A-Za-z0-9._-]{6,64}$/);
export const reasonSchema = z.string().trim().min(5).max(500);
export const vndSchema = z.number().int().min(0).max(1_000_000_000);

export const settingsSchema = z.object({
  autoEnabled: z.boolean(),
  autoLimit: vndSchema,
  dailyCap: vndSchema,
});
