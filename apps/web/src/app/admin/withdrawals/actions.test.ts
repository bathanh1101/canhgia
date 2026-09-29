import { beforeEach, describe, expect, it, vi } from "vitest";

const state = vi.hoisted(() => ({
  rpc: vi.fn(),
  target: { data: null as unknown, error: null as unknown },
  filters: [] as [string, unknown][],
}));
vi.mock("@/lib/admin/require-admin", () => ({
  requireAdmin: async () => {
    const q: unknown = new Proxy({}, {
      get: (_t, m: string) => m === "maybeSingle" ? async () => state.target
        : m === "eq" ? (k: string, v: unknown) => { state.filters.push([k, v]); return q; } : () => q,
    });
    return { supabase: { rpc: state.rpc, from: () => q }, adminId: "admin-1", email: "a@x" };
  },
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import { getPayoutTarget, markPaid } from "./actions";

const id = "1a2b3c4d-1111-4222-8333-444455556666";

describe("markPaid", () => {
  beforeEach(() => { state.rpc.mockReset(); state.filters = []; });

  it("pays exactly one id with a valid ref", async () => {
    state.rpc.mockResolvedValue({ data: [{ id, ok: true, error: null }], error: null });
    const r = await markPaid(id, "FT26100512345");
    expect(r.ok).toBe(true);
    expect(state.rpc).toHaveBeenCalledWith("admin_mark_paid", { p_ids: [id], p_transfer_ref: "FT26100512345" });
  });

  it("rejects bad ids and refs without calling the DB", async () => {
    expect((await markPaid("nope", "FT26100512345")).ok).toBe(false);
    expect((await markPaid(id, "x")).ok).toBe(false);
    expect(state.rpc).not.toHaveBeenCalled();
  });

  it("maps the unique-ref violation to a clear message", async () => {
    state.rpc.mockResolvedValue({ data: null, error: { code: "23505", message: "duplicate key" } });
    const r = await markPaid(id, "FT26100512345");
    expect(r).toEqual({ ok: false, error: expect.stringContaining("đã được dùng") });
  });
});

describe("getPayoutTarget", () => {
  beforeEach(() => { state.filters = []; });

  it("only reads rows this admin has claimed", async () => {
    state.target = { data: { account_number: "1020304050", account_name: "A" }, error: null };
    const r = await getPayoutTarget(id);
    expect(r).toEqual({ ok: true, message: undefined, data: { accountNumber: "1020304050", accountName: "A" } });
    expect(state.filters).toContainEqual(["claimed_by", "admin-1"]);
    expect(state.filters).toContainEqual(["status", "processing"]);
  });

  it("fails when the row is not claimed by me", async () => {
    state.target = { data: null, error: null };
    expect((await getPayoutTarget(id)).ok).toBe(false);
  });
});
