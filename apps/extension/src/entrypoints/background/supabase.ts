import { createClient } from '@supabase/supabase-js'
import { chromeStorage } from '../../lib/chrome-storage-adapter'
import { SUPABASE_KEY, SUPABASE_URL } from '../../lib/config'
import { makeEdgePost } from '../../lib/edge-client'

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { storage: chromeStorage, persistSession: true, detectSessionInUrl: false, autoRefreshToken: false, flowType: 'implicit' },
})

/** SW can sleep for hours: getSession() refreshes an expired/near-expiry token before every call. */
export async function getToken(): Promise<string | null> {
  const { data, error } = await supabase.auth.getSession()
  return error ? null : data.session?.access_token ?? null
}

export const edgePost = makeEdgePost({ url: SUPABASE_URL, key: SUPABASE_KEY, getToken })
