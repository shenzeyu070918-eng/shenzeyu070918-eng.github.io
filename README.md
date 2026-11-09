# Jeremy Shen — personal homepage

The homepage remains a build-free GitHub Pages site. `version3.html` is retained as a historical version.

## DeepSeek avatar

The chat posts to the `jeremy-chat` Supabase Edge Function. The function adds the curated profile in `supabase/functions/jeremy-chat/profile.mjs` and sends recent conversation to DeepSeek. No conversations or raw IP addresses are stored by this implementation.

- Default model: `deepseek-flash`, non-thinking mode, maximum 600 output tokens.
- Required server secret: `DEEPSEEK_API_KEY`.
- Optional server secret: `DEEPSEEK_MODEL` to override the model.
- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by the Edge Function environment; never copy them into the homepage.
- `public-client-key.mjs` contains the existing **public** browser key, not a model or server secret. Rotate it alongside the frontend configuration if necessary.
- Allowed browser origin: `https://shenzeyu070918-eng.github.io`.
- The function checks the public application key itself, with `verify_jwt = false`, so visitors do not need to log in. The public key and origin checks do not authenticate visitors.
- Database-backed quotas cap the entire site at 200 requests per UTC day. Forwarded-address counters additionally allow 6 requests per minute and 60 per day. Requests consume quota before the paid model call; failures can also consume quota. Quota storage errors fail closed.
- Only HMAC address digests and counters are stored. Quotas remain effective across function instances and restarts. Set a separate provider budget as desired.

Apply `supabase/avatar-rate-limit.sql` once to create the isolated quota counters and service-only RPC, then deploy all files in `supabase/functions/jeremy-chat/`. Configure the DeepSeek key through Supabase Dashboard → Edge Functions → Secrets. Never commit the key.

## Verification

`tests/avatar.test.mjs` exports `runChecks()`. Run with a modern Node runtime:

```sh
node --input-type=module -e "const {runChecks}=await import('./tests/avatar.test.mjs'); console.log(await runChecks())"
```

These checks use a mocked model service to verify validation, quotas, upstream errors and history. Live model accuracy and network availability must also be checked separately.

Official API documentation: https://api-docs.deepseek.com/
