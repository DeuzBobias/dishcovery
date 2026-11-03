begin;
create table if not exists public.community_recipes (
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  recipe_id text not null check (length(recipe_id) between 1 and 180),
  recipe jsonb not null check (jsonb_typeof(recipe) = 'object'),
  posted_at timestamptz not null default now(),
  primary key(owner_id, recipe_id)
);
create index if not exists community_recipes_recent on public.community_recipes(posted_at desc);
alter table public.community_recipes enable row level security;
revoke all on public.community_recipes from public, anon, authenticated;
grant select,delete on public.community_recipes to authenticated;
grant insert(owner_id,recipe_id,recipe),update(recipe) on public.community_recipes to authenticated;
drop policy if exists community_read on public.community_recipes;
create policy community_read on public.community_recipes for select to authenticated using(true);
drop policy if exists community_insert on public.community_recipes;
create policy community_insert on public.community_recipes for insert to authenticated with check(owner_id=(select auth.uid()));
drop policy if exists community_update on public.community_recipes;
create policy community_update on public.community_recipes for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
drop policy if exists community_delete on public.community_recipes;
create policy community_delete on public.community_recipes for delete to authenticated using(owner_id=(select auth.uid()));
-- Update only the recipe document on conflict. RLS remains in force.
create or replace function public.publish_recipe(recipe_id_arg text, recipe_arg jsonb)
returns void language sql security invoker set search_path='' as $$
 insert into public.community_recipes(owner_id,recipe_id,recipe) values(auth.uid(),recipe_id_arg,recipe_arg)
 on conflict(owner_id,recipe_id) do update set recipe=excluded.recipe;
$$;
revoke all on function public.publish_recipe(text,jsonb) from public,anon;
grant execute on function public.publish_recipe(text,jsonb) to authenticated;
commit;
