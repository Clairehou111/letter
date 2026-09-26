# Supabase Auth email templates

These files are the source-controlled versions of Letter Within's hosted
Supabase Auth emails. Supabase does not deploy them from this directory
automatically.

## Magic link

- Dashboard template: **Authentication > Email Templates > Magic Link**
- Subject: `Your link to Letter Within`
- Body: [`magic-link.html`](magic-link.html)

The same template handles returning-user sign-in and first-time account
creation because the mobile client calls `signInWithOtp` with
`shouldCreateUser: true`.

Keep `{{ .ConfirmationURL }}` intact. It contains the one-time Supabase
verification URL and the allow-listed `app.letterwithin://login-callback`
redirect used by the mobile app.

After changing the hosted template, validate delivery and callback completion
on both iOS and Android. Disable link tracking in the SMTP provider: automated
URL rewriting or link scanning can interfere with a one-time authentication
link.
