/** Test support: chainable PostgREST stand-in returning canned rows per table (no network). */
export function fakeSupabase(tables: Record<string, unknown[]> = {}, opts: { signedUrl?: string; fnResult?: unknown } = {}) {
  const chain = (table: string) => {
    const result = { data: tables[table] ?? [], count: (tables[table] ?? []).length, error: null };
    const proxy: unknown = new Proxy(() => undefined, {
      get: (_t, prop) => {
        if (prop === "then") return (res: (v: unknown) => unknown) => Promise.resolve(result).then(res);
        if (prop === "maybeSingle" || prop === "single") return () => Promise.resolve({ ...result, data: (result.data as unknown[])[0] ?? null });
        return () => proxy;
      },
    });
    return proxy;
  };
  return {
    from: (table: string) => chain(table),
    rpc: async () => ({ data: null, error: null }),
    storage: { from: () => ({ createSignedUrl: async () => ({ data: { signedUrl: opts.signedUrl ?? "https://signed.test/img" }, error: null }) }) },
    functions: { invoke: async () => ({ data: opts.fnResult ?? { rows: [], clicks: [] }, error: null }) },
  };
}
