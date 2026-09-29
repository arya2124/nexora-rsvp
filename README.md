# NEXORA RSVP Portal — Supabase version

This version connects the public RSVP page and admin check-in dashboard to your Supabase project.

## Before testing
1. In Supabase SQL Editor, run `SUPABASE_SETUP.sql` (one logical block at a time).
2. In Authentication → Users, create the NEXORA admin email/password you will use for `admin.html`.
3. Serve the folder from a local web server or deploy it to a static host; do not rely on `file://` if QR camera permissions are blocked.

## Files
- `index.html` — public RSVP + ticket
- `admin.html` — authenticated admin QR/manual check-in
- `config.js` — Supabase URL + publishable key
- `SUPABASE_SETUP.sql` — database functions/policies
- `assets/nexora-logo.jpeg` — event logo

The browser uses only the Supabase publishable key. Never put a Supabase secret/service-role key in the website.
