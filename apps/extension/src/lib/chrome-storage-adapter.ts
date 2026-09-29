// supabase-js auth storage on chrome.storage.local (background only; content scripts never see tokens).
export const chromeStorage = {
  getItem: async (k: string): Promise<string | null> => ((await chrome.storage.local.get(k))[k] as string | undefined) ?? null,
  setItem: (k: string, v: string): Promise<void> => chrome.storage.local.set({ [k]: v }),
  removeItem: (k: string): Promise<void> => chrome.storage.local.remove(k),
}
