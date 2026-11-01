-- Run in your Supabase SQL editor. Each account can access only its own kitchen.
create table if not exists public.kitchens (
 user_id uuid primary key references auth.users(id) on delete cascade,
 payload jsonb not null default '{}'::jsonb,
 revision bigint not null default 1,
 updated_at timestamptz not null default now()
);
alter table public.kitchens enable row level security;
revoke all on public.kitchens from anon,authenticated;
grant select on public.kitchens to authenticated;
drop policy if exists "Read own kitchen" on public.kitchens;
create policy "Read own kitchen" on public.kitchens for select to authenticated using ((select auth.uid()) = user_id);
create or replace function public.save_kitchen(expected_revision bigint, new_payload jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); result bigint;
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if jsonb_typeof(new_payload) <> 'object' then raise exception 'Invalid payload'; end if;
 if expected_revision = 0 then
  insert into public.kitchens(user_id,payload,revision) values(uid,new_payload,1) on conflict do nothing returning revision into result;
 else
  update public.kitchens set payload=new_payload, revision=revision+1,updated_at=now()
  where user_id=uid and revision=expected_revision returning revision into result;
 end if;
 if result is null then raise exception 'Sync conflict' using errcode='40001'; end if;
 return result;
end $$;
revoke all on function public.save_kitchen(bigint,jsonb) from public,anon;
grant execute on function public.save_kitchen(bigint,jsonb) to authenticated;
