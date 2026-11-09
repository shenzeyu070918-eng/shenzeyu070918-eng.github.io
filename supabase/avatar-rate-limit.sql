-- Private counters only: no chat content or raw IP addresses are stored.
create schema if not exists avatar_private;
revoke all on schema avatar_private from public, anon, authenticated;
grant usage on schema avatar_private to service_role;

create table avatar_private.request_buckets (
  bucket text primary key,
  hits integer not null check (hits > 0),
  expires_at timestamptz not null
);
alter table avatar_private.request_buckets enable row level security;
revoke all on avatar_private.request_buckets from public, anon, authenticated;
grant select, insert, update, delete on avatar_private.request_buckets to service_role;

create function public.consume_avatar_quota(client_hash text)
returns boolean language plpgsql security invoker
set search_path = ''
as $$
declare
  tick timestamptz := clock_timestamp();
  minute_id bigint := floor(extract(epoch from tick) / 60);
  day_id bigint := floor(extract(epoch from tick) / 86400);
  slot record;
  consumed integer;
begin
  if client_hash !~ '^[a-f0-9]{64}$' then return false; end if;
  delete from avatar_private.request_buckets where expires_at < tick;
  for slot in select * from (values
    ('minute:' || minute_id || ':' || client_hash, 6, tick + interval '2 minutes'),
    ('day:' || day_id || ':' || client_hash, 60, tick + interval '2 days'),
    ('global:' || day_id, 200, tick + interval '2 days')
  ) as limits(bucket, max_hits, expires_at)
  loop
    consumed := null;
    insert into avatar_private.request_buckets as b(bucket, hits, expires_at)
    values (slot.bucket, 1, slot.expires_at)
    on conflict (bucket) do update set hits = b.hits + 1
      where b.hits < slot.max_hits
    returning hits into consumed;
    if consumed is null then return false; end if;
  end loop;
  return true;
end;
$$;
revoke all on function public.consume_avatar_quota(text) from public, anon, authenticated;
grant execute on function public.consume_avatar_quota(text) to service_role;
