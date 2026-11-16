import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';
import { SignJWT, importPKCS8 } from 'npm:jose@5.10.0';
import {
  PayloadTooLargeError,
  extractBearerToken,
  isActiveAdmin,
  isPushDiagnosticRequest,
  isValidAnnouncementRequest,
  publicPushFailure,
  readJsonWithLimit,
} from './pushSecurity.js';
import { diagnosePushSetup } from './pushDiagnostics.js';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

async function apnsBearer(key: string, keyId: string, teamId: string) {
  const privateKey = await importPKCS8(key.replace(/\\n/g, '\n'), 'ES256');
  return new SignJWT({}).setProtectedHeader({ alg: 'ES256', kid: keyId, typ: 'JWT' }).setIssuedAt().setIssuer(teamId).setExpirationTime('1h').sign(privateKey);
}

async function sendAPNs(token: string, title: string, body: string, topic: string, environment: string, bearer: string) {
  const host = environment === 'sandbox' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
  const response = await fetch(`${host}/3/device/${encodeURIComponent(token)}`, {
    method: 'POST',
    headers: { authorization: `bearer ${bearer}`, 'apns-topic': topic, 'apns-push-type': 'alert', 'apns-priority': '10', 'content-type': 'application/json' },
    body: JSON.stringify({ aps: { alert: { title, body }, sound: 'default' } }),
  });
  return { ok: response.ok, status: response.status };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  let failureStage = 'authentication';
  try {
    const token = extractBearerToken(req.headers.get('Authorization'));
    if (!token) return json({ error: 'unauthorized' }, 401);
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) throw new Error('server configuration unavailable');
    const db = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: authData, error: authError } = await db.auth.getUser(token);
    if (authError || !authData?.user) return json({ error: 'unauthorized' }, 401);
    failureStage = 'admin_profile_lookup';
    const { data: profile, error: profileError } = await db.from('profiles').select('role,is_active').eq('id', authData.user.id).maybeSingle();
    if (profileError) throw profileError;
    if (!isActiveAdmin(profile)) return json({ error: 'forbidden' }, 403);
    failureStage = 'request_body';
    let requestBody;
    try { requestBody = await readJsonWithLimit(req, 8192); } catch (error) { if (error instanceof PayloadTooLargeError) return json({ error: 'request_too_large' }, 413); return json({ error: 'invalid_json' }, 400); }
    if (isPushDiagnosticRequest(requestBody)) {
      const diagnostic = await diagnosePushSetup({
        getEnv: (name: string) => Deno.env.get(name),
        setVapidDetails: (subject: string, publicKey: string, privateKey: string) => webpush.setVapidDetails(subject, publicKey, privateKey),
        loadActiveSubscriptions: async () => { const { count, error } = await db.from('push_subscriptions').select('id,profiles!inner(group_type,is_active)', { count: 'exact', head: true }).eq('profiles.is_active', true); return { count, error }; },
      });
      return json(diagnostic);
    }
    if (!isValidAnnouncementRequest(requestBody)) return json({ error: 'invalid_announcement_id' }, 400);
    failureStage = 'announcement_lookup';
    const { data: announcement, error: announcementError } = await db.from('announcements').select('title,message,target_group,is_active').eq('id', requestBody.announcement_id).maybeSingle();
    if (announcementError) throw announcementError;
    if (!announcement || !announcement.is_active) return json({ error: 'not_found' }, 404);
    const targetGroup = announcement.target_group;
    let webQuery = db.from('push_subscriptions').select('id,subscription_data,profiles!inner(group_type,is_active)').eq('profiles.is_active', true);
    if (targetGroup) webQuery = webQuery.eq('profiles.group_type', targetGroup);
    const { data: subscriptions, error: subscriptionsError } = await webQuery;
    if (subscriptionsError) throw subscriptionsError;
    let webSent = 0; const expiredWebIds: string[] = [];
    const vapidSubject = Deno.env.get('VAPID_SUBJECT'); const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY'); const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY');
    if (vapidSubject && vapidPublicKey && vapidPrivateKey) {
      webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);
      await Promise.all((subscriptions ?? []).map(async (subscription: any) => { try { await webpush.sendNotification(subscription.subscription_data, JSON.stringify({ title: announcement.title, body: announcement.message }), { TTL: 86400 }); webSent += 1; } catch (error: any) { if (error?.statusCode === 404 || error?.statusCode === 410) expiredWebIds.push(subscription.id); } }));
    }
    if (expiredWebIds.length) await db.from('push_subscriptions').delete().in('id', expiredWebIds);
    let apnsSent = 0; const expiredApnsIds: string[] = [];
    const apnsKey = Deno.env.get('APNS_PRIVATE_KEY'); const apnsKeyId = Deno.env.get('APNS_KEY_ID'); const apnsTeamId = Deno.env.get('APNS_TEAM_ID'); const apnsTopic = Deno.env.get('APNS_BUNDLE_ID') || 'com.gharibg70.coaster';
    if (apnsKey && apnsKeyId && apnsTeamId) {
      const bearer = await apnsBearer(apnsKey, apnsKeyId, apnsTeamId);
      let deviceQuery = db.from('push_devices').select('id,token,environment,profiles!inner(group_type,is_active)').eq('platform', 'ios').eq('profiles.is_active', true);
      if (targetGroup) deviceQuery = deviceQuery.eq('profiles.group_type', targetGroup);
      const { data: devices, error: devicesError } = await deviceQuery;
      if (devicesError) throw devicesError;
      await Promise.all((devices ?? []).map(async (device: any) => { try { const result = await sendAPNs(device.token, announcement.title, announcement.message, apnsTopic, device.environment || 'production', bearer); if (result.ok) apnsSent += 1; else if (result.status === 400 || result.status === 410 || result.status === 404) expiredApnsIds.push(device.id); } catch { /* one device must not block the batch */ } }));
      if (expiredApnsIds.length) await db.from('push_devices').delete().in('id', expiredApnsIds);
    }
    return json({ sent: webSent + apnsSent, web_sent: webSent, apns_sent: apnsSent, total_web: subscriptions?.length ?? 0 });
  } catch { console.error(`send-push internal failure stage=${failureStage}`); return json(publicPushFailure(), 500); }
});
