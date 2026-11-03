insert into public.dishcovery_media_config (id, origin)
values (true, 'https://dishcovery-media.bobiasdeuz.workers.dev')
on conflict (id) do update set origin = excluded.origin;
