# Dishcovery photo storage

`dishcovery-media` serves a private R2 Standard bucket through a Worker. The Worker verifies each request with Dishcovery's Supabase Auth service. A member can read their own images. Other members can read an image referenced by that owner's published recipe. The app stores an object reference, so a private kitchen sync does not have to copy the uploaded bytes. Existing embedded photos continue to display. Guest photos stay local.

## Activate the service

The Dishcovery production Worker is deployed at `https://dishcovery-media.bobiasdeuz.workers.dev` with `PHOTOS` bound to the private Standard bucket `dishcovery-photos`. Migration `202611030003_activate_media.sql` records the production endpoint for APK 1.2.0 and later. Use the steps below to reproduce the setup on another account.

1. The Cloudflare account owner activates R2 and reviews the account's billing terms. Standard storage includes a monthly free allowance with usage-based overages.
2. Create the private Standard bucket `dishcovery-photos`. Keep public bucket access disabled.
3. Deploy `worker.mjs` as a Worker named `dishcovery-media` with the `PHOTOS` R2 binding and the two public Supabase variables specified in `wrangler.jsonc`. An owner using an already authorized Wrangler CLI can run `npx wrangler r2 bucket create dishcovery-photos` and `npx wrangler deploy --config cloudflare/wrangler.jsonc` from the repository root. No Supabase service-role key is used.
4. Confirm that an unauthenticated request to the deployed image route returns HTTP 401. Apply `supabase/migrations/202611030002_media_endpoint.sql`. Store the verified **actual Worker origin** in Supabase using the following template, substituting your workers.dev subdomain.

```sql
insert into public.dishcovery_media_config(id, origin)
values (true, 'https://dishcovery-media.YOUR-SUBDOMAIN.workers.dev')
on conflict (id) do update set origin=excluded.origin;
```

The Android app discovers the endpoint at runtime. Until an origin is configured, it continues to use its previous embedded-photo format. Current uploads accept JPEG, PNG and WebP up to 3 MiB. The Worker deduplicates identical bytes per member and photo type and limits new objects per member. Cloudflare's account billing is independent of that app limit.

## Check on two phones

Sign in as different members. On phone A add a recipe photo and choose **Post to community**, then **Save and post recipe**. For a previously saved recipe, open it and tap **Post to community**. On phone B, open Home and tap the refresh icon beside **From the community**. Open the post and compare its ingredients and photo. For an R2 deployment, also check the object exists in `dishcovery-photos`. Profile photos can be changed under Profile → Personal Data.
