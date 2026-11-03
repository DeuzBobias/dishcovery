create table if not exists public.dishcovery_media_config (
 id boolean primary key default true check(id),
 origin text not null check(origin ~ '^https://dishcovery-media\.[a-z0-9-]+\.workers\.dev$')
);
alter table public.dishcovery_media_config enable row level security;
revoke all on public.dishcovery_media_config from public, anon, authenticated;
grant select on public.dishcovery_media_config to authenticated;
drop policy if exists read_media_origin on public.dishcovery_media_config;
create policy read_media_origin on public.dishcovery_media_config for select to authenticated using(true);
