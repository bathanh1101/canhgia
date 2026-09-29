import { makeHandler } from './handler.ts'
import { adminClient } from '../_shared/supabase-admin-client.ts'
import { createFcmClient } from '../_shared/fcm-client.ts'

const projectId = Deno.env.get('FCM_PROJECT_ID')
const sa = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')
if (!projectId || !sa) throw new Error('missing env FCM_PROJECT_ID / FCM_SERVICE_ACCOUNT_JSON')
Deno.serve(makeHandler({ db: adminClient(), fcm: createFcmClient({ projectId, serviceAccountJson: sa }) }))
