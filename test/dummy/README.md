# Dummy App

This Rails app proves `recording_studio_broadcasts` in a real host. It mounts Recording Studio Admin at `/admin` with Broadcasts as the first section.

## What It Covers

- An `AdminRoot` recordable whose `recording_studio_admin_sections` list includes `:broadcasts`
- Admin access through Recording Studio Accessible, with an admin and a view-only user
- A `:registered_after` filter over `User.all`
- Email through `recording_studio_notifications_email`, sent from `Broadcasts <broadcasts@example.com>`
- The Recording Studio default layout and FlatPack assets
- Turbo, so the broadcasts table replaces its placeholder, plus the admin Stimulus controllers Admin's install generator pins

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Sign in with either user:

- `admin@admin.com` / `Password` can write, test, schedule, send, cancel, and delete broadcasts
- `viewer@example.com` / `Password` can open broadcasts but not change or send them

Seeds also add a few users with different join dates so the filter has something to narrow.

Development mail is written to `tmp/mails`. Tests use `:test`. Neither reaches a real mail server.

## Useful Routes

- `/` redirects to `/admin`
- `/admin` shows the Broadcasts section
- `/admin/screens/broadcasts` lists broadcasts
- `/admin/broadcasts/new` writes a new one
- `/notifications` holds notification settings and unsubscribe links
- `/users/sign_in` is the Devise sign-in page
- `/up` is the Rails health check

## Root Switcher

Admin checks that the current root is the admin root. The root switcher's first scope, `admin`, lists the admin root for anyone with view access, so it is the default current root. The `all_workspaces` scope keeps the template's workspace roots.
