# Supabase account boundary

Letter Within uses Supabase only for account identity. Health, cycle, symptom, Letter Within,
and Care records are not stored here.

Deploy `functions/delete-account` with Supabase's standard `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` function secrets, plus a RevenueCat secret API key
as `REVENUECAT_SECRET_API_KEY`. The function deletes the RevenueCat customer
whose App User ID is the Supabase UUID before deleting the Supabase identity.
Keep JWT verification enabled. Deleting the RevenueCat customer does not cancel
an App Store or Google Play subscription; cancellation remains store-managed.
Add `app.letterwithin://login-callback` to Auth redirect URLs and enable Apple and
email OTP providers before release.
