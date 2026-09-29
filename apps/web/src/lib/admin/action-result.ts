import { errorMessage } from "@/lib/errors/error-messages";

/** Return type of every admin server action. `error` is already Vietnamese. */
export type ActionResult<T = undefined> =
  | { ok: true; message?: string; data?: T }
  | { ok: false; error: string };

export const ok = <T = undefined>(message?: string, data?: T): ActionResult<T> => ({ ok: true, message, data });

/** Wraps a Supabase/PostgREST error (message = error code) into a failed result. */
export const fail = (err: unknown): ActionResult<never> => ({ ok: false, error: errorMessage(err) });
