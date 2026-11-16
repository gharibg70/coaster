-- Native APNs devices and narrow admin operations.
create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  token text not null unique,
  bundle_id text,
  environment text not null default 'production' check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists push_devices_user_idx on public.push_devices(user_id, platform);
alter table public.push_devices enable row level security;
drop policy if exists "Users manage own native push devices" on public.push_devices;
create policy "Users manage own native push devices" on public.push_devices
  for all to authenticated using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

do $$ begin
  alter publication supabase_realtime add table public.push_devices;
exception when duplicate_object then null;
end $$;

create or replace function public.admin_renew_subscription(p_subscription_id uuid, p_days integer default 30)
returns date language plpgsql security definer set search_path = '' as $$
declare v_end date;
begin
  if not public.is_admin() then raise exception 'admin only' using errcode = '42501'; end if;
  if p_days < 1 or p_days > 366 then raise exception 'invalid renewal days' using errcode = '22023'; end if;
  update public.subscriptions
    set end_date = greatest(coalesce(end_date, current_date), current_date) + p_days,
        status = 'active'::public.subscription_status
    where id = p_subscription_id
    returning end_date into v_end;
  if not found then raise exception 'subscription not found' using errcode = '22023'; end if;
  return v_end;
end;
$$;

create or replace function public.admin_set_subscription_status(p_subscription_id uuid, p_status public.subscription_status)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'admin only' using errcode = '42501'; end if;
  update public.subscriptions set status = p_status where id = p_subscription_id;
  if not found then raise exception 'subscription not found' using errcode = '22023'; end if;
end;
$$;

create or replace function public.admin_set_seat_capacity(p_capacity integer)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'admin only' using errcode = '42501'; end if;
  if p_capacity < 1 or p_capacity > 10000 then raise exception 'invalid seat capacity' using errcode = '22023'; end if;
  insert into public.system_settings(key, value, updated_at)
    values ('seat_capacity', to_jsonb(p_capacity), now())
    on conflict (key) do update set value = excluded.value, updated_at = excluded.updated_at;
end;
$$;

create or replace function public.admin_set_destination(p_direction text, p_lat double precision, p_lng double precision, p_radius_meters integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_key text;
begin
  if not public.is_admin() then raise exception 'admin only' using errcode = '42501'; end if;
  if p_direction not in ('outbound', 'return') or p_lat not between -90 and 90 or p_lng not between -180 and 180 or p_radius_meters < 10 or p_radius_meters > 50000 then
    raise exception 'invalid destination' using errcode = '22023';
  end if;
  v_key := case when p_direction = 'outbound' then 'arrival_destination_outbound' else 'arrival_destination_return' end;
  insert into public.system_settings(key, value, updated_at)
    values (v_key, jsonb_build_object('lat', p_lat, 'lng', p_lng, 'radiusMeters', p_radius_meters), now())
    on conflict (key) do update set value = excluded.value, updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.admin_renew_subscription(uuid, integer) from public, anon;
revoke all on function public.admin_set_subscription_status(uuid, public.subscription_status) from public, anon;
revoke all on function public.admin_set_seat_capacity(integer) from public, anon;
revoke all on function public.admin_set_destination(text, double precision, double precision, integer) from public, anon;
grant execute on function public.admin_renew_subscription(uuid, integer) to authenticated;
grant execute on function public.admin_set_subscription_status(uuid, public.subscription_status) to authenticated;
grant execute on function public.admin_set_seat_capacity(integer) to authenticated;
grant execute on function public.admin_set_destination(text, double precision, double precision, integer) to authenticated;
