# Changelog

## [Unreleased]

## [0.7.0]

### Changed

- The gemspec cap on FlatPack is `< 1.0`. The floor stays `>= 0.1.376`, so a host on FlatPack 0.1.x still resolves and FlatPack 0.2 resolves.
- Development and dummy pins are FlatPack `~> 0.2` (`v0.2.0`), Recording Studio `~> 7.8` (`v7.8.0`), Accessible `~> 0.58` (`v0.58.0`), Admin `~> 2.20` (`v2.20.0`), Attachable `~> 0.34` (`v0.34.0`), Notifications `~> 0.21` (`v0.21.0`), Notifications Email `~> 0.7` (`v0.7.0`), Publishable `~> 1.5` (`v1.5.0`), Root Switchable `~> 0.17` (`v0.17.0`), Trashable `~> 1.3` (`v1.3.0`), Cache `~> 0.8` (`v0.8.0`), Icons `~> 0.5` (`v0.5.0`), Logs `~> 0.9` (`v0.9.0`), Metrics `~> 0.10` (`v0.10.0`), Moveable `~> 6.1` (`v6.1.0`), and API `~> 1.21` (`v1.21.2`).
- Other gemspec ranges are unchanged: Rails `~> 8.1.0`, Recording Studio `>= 7.0`, `< 8.0`, Accessible `>= 0.44.0`, `< 1.0`, Admin `>= 2.16.0`, `< 3.0`, Attachable `>= 0.28.0`, `< 1.0`, Notifications `>= 0.18.0`, `< 1.0`, Notifications Email `>= 0.5.4`, `< 1.0`, and Publishable `>= 1.0.0`.

### Upgrade notes

- Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not. This gem does not ship those core migrations.
- flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.
- Notifications 0.21.0 adds `20261119120000_add_inbound_replies_to_recording_studio_notifications`. API 1.21.2 adds `20261117000024_add_owner_to_recording_studio_api_api_clients` on an existing API clients table. No Broadcasts migration.
- Compare [v0.6.0...v0.7.0](https://github.com/bowerbird-app/RecordingStudio_broadcasts/compare/v0.6.0...v0.7.0).

## [0.6.0]

### Changed

- Requires Publishable `>= 1.0.0`. This is a breaking change. Publishable 1.0.0 removed `RecordingStudioPublishable::Hooks` and `RecordingStudioPublishable.configuration.hooks`.
- The sent-broadcast lock and the external-write listener register on `RecordingStudio.configuration.hooks`. The lock is an `around_service` hook at priority 0, so it wraps hooks at the default priority of 100. It refuses Publishable Update and Transition on a sent broadcast and calls the next hook for every other service. The `after_service` listener returns immediately unless the service is one of those two.
- `install_publish_delivery!` can run again after `RecordingStudio.configuration.hooks.clear!` or a failed boot. A repeat call does not subscribe twice, so one published event still sends once.
- `RecordingStudioPublishable.subscribe` for `:published`, `:unpublished`, and `:revised` is unchanged. `register_public_renderer` is unchanged.
- Development and dummy pins use Publishable `v1.0.0`. Recording Studio stays `v7.0.0` (`>= 7.0`, `< 8.0`).

### Upgrade notes

- Pin `recording_studio_publishable` to tag `v1.0.0` or newer and remove a `< 1.0` cap. Recording Studio stays `>= 7.0`, `< 8.0`. No Broadcasts migration.
- Delete host code that calls `RecordingStudioPublishable.configuration.hooks` or `RecordingStudioPublishable::Hooks`. Register service hooks on `RecordingStudio.configuration.hooks` and filter by service class. Core runs those hooks for every gem.
- Leave `RecordingStudioPublishable.subscribe(:published)`, `:unpublished`, and `:revised` in place.

## [0.5.0]

### Changed

- Requires Recording Studio 7 (`>= 7.0`, `< 8.0`). Sibling floors are open below the next major: Accessible `>= 0.44.0`, Admin `>= 2.16.0` (`< 3.0`), Attachable `>= 0.28.0`, Notifications `>= 0.18.0`, Notifications Email `>= 0.5.4`, and Publishable `>= 0.18.1`. FlatPack is `>= 0.1.376`, `< 0.2`.
- Development and dummy pins are Recording Studio `v7.0.0`, those floors, and the GitHub gems Bundler needs with them: API `v0.24.0`, Moveable `v5.0.0`, Trashable `v0.17.0`, Metrics `v0.9.0`, Cache `v0.6.3`, Icons `v0.2.1`, Logs `v0.8.0`, Root Switchable `v0.16.0`, and FlatPack `v0.1.376`. Puma is `8.1.0`. msgpack stays `>= 1.8.7`.
- Creating a root uses `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` only finds an existing root.
- Kept rows use `RecordingStudio::Recording.kept`. The dummy admin config sets `access_recording_resolver` only.

### Upgrade notes

- Pin Recording Studio `v7.0.0` or newer, below 8. Run `bin/rails generate recording_studio:migrations` so `recording_studio_events.root_recording_id` exists. `config.authorize_write` still runs when a root is created, and `root_recording` is nil on that call.
- Calls that created a root by using `root_recording_for` now call `create_root_recording!`. Lookups stay on `root_recording_for` and can return nil.
- Replace `recording_studio_trashable_kept_sql` with `Recording.kept`. Remove `site_admin_recording_resolver`.
- `RecordingStudioNotifications.notify` and `notify_fan_out` take the same arguments Broadcasts already passes. No Broadcasts migration.
- Root Switchable 0.16 refuses the switcher unless the actor has Accessible view on the current root.

## [0.4.0]

### Changed

- Sending enqueues `RecordingStudioNotifications.notify_fan_out` for the `recording_studio_broadcasts.snapshot` recipient scope. Notifications inserts the snapshotted audience in chunks of 1,000 and dedupes on one idempotency key per broadcast (`broadcast/<recording id>`).
- `config.batch_size` is removed. Broadcasts no longer claims recipient rows or calls `notify` once per person.

### Upgrade notes

- Pin `recording_studio_notifications` to `v0.16.0` or newer, below `0.17`, and FlatPack to `v0.1.353` or newer. Notifications 0.16.0 requires that FlatPack. No Broadcasts migration.
- Remove `config.batch_size` from the Broadcasts initializer.
- Cancel still skips snapshot rows that are waiting. Fan-out has no cancel hook, so a chunk already loaded (up to 1,000 people) can still be emailed. Later chunks read the snapshot again and leave cancelled rows out.
- Fan-out does not write `recording_studio_broadcast_recipients`. Broadcasts still records sent, preference skip, suppression skip, and failure on those rows, which is what the detail page counts.
- A test send still uses synchronous `notify` with its own idempotency key, so the page can tell a first test from a repeat.

## [0.3.2]

### Changed

- Deleting a broadcast loads every snapshot with `recordables(all: true)`. Recording Studio 6.12.0 returns 50 by default and pages with `limit:` and `cursor:`. A draft with more than 50 revisions would otherwise leave the older snapshots in `recording_studio_broadcasts`.
- Development and dummy pins, and the dependency floor, are Recording Studio `v6.12.0`.

### Upgrade notes

- Hosts must pin Recording Studio `v6.12.0` or newer. Delete calls `recordables(all: true)`, which that release added.
- Run `bin/rails generate recording_studio:migrations`, then migrate. That installs `root_recording_id` on `recording_studio_events`.
- Set `config.authorize_write` so a present actor may write. Core 6.12 rejects a write when that callback is missing.

## [0.3.1]

### Changed

- Show-page section headings (Who gets it, Delivery, Schedule) use Flatpack `SectionTitle` (`size: :md`) instead of `PageTitle` `variant: :h2`.

## [0.3.0]

### Changed

- Dummy and development pins use FlatPack `v0.1.341`, Admin `v2.9.1`, Root Switchable `v0.11.5`, and Recording Studio `v6.3.0` so `view_component` stays at 4.14 or newer.
- Lockfiles pin rack 3.2.8.
- Send no longer pre-checks notification preferences. `RecordingStudioNotifications.notify` already drops optional email when the preference is off and returns `nil`. Broadcasts treats that as a preference skip. Audience preview still checks the preference so Ready / Left out counts stay honest.
- Audience eligibility resolves addresses through `RecordingStudioNotificationsEmail.config.recipients`, not a second `email` / `name` lookup on Broadcasts.
- Returning a scheduled broadcast to draft after an outside Publishable edit retries only `InvalidTransition`, `RecordInvalid`, and `RecordNotSaved`. Other errors raise.

### Upgrade notes

- Hosts must pin FlatPack `v0.1.341` or newer, Admin `v2.9.1` or newer, Recording Studio `v6.3.0` or newer, Notifications `v0.14.8`, the email channel `v0.5.2`, Attachable `v0.22.0`, and Publishable `v0.13.0`. Admin also needs Logs `v0.7.3`.
- Stop passing `email:` and `name:` to `RecordingStudioBroadcasts.config.recipients`. Pass `relation:` only. If an address is not `#email`, register the same lookup once on the email channel: `RecordingStudioNotificationsEmail.config.recipients.register("User", ->(user) { user.contact_email })`.

## [0.2.2]

### Changed

- Cursor Cloud environment name is `recording-studio-broadcasts`.
- Dummy PostgreSQL databases default to `broadcasts_development`, `broadcasts_test`, and `broadcasts_production`.
- README install pin for this gem matches shipped tag `v0.2.1`.
- GitHub Actions `setup-ruby` steps that read `.ruby-version` now request `3.3`, so ubuntu-latest can install a 3.3 patch that exists on 26.04. Matrix jobs are unchanged.
- Dummy schedule tests and seeds use a time relative to the clock, so a hard-coded send day cannot go stale.

## [0.2.1]

### Added

- Once a broadcast has been sent, Publishable writes that would change the send clock are refused. Edit redirects to the broadcasts list. Edit and Delete stay hidden on the admin resource. Cancel and completing a send still run.

## [0.2.0]

### Added

- A broadcast's send time is Recording Studio Publishable's `publish_at` (git tag `v0.9.1`). Scheduling stores that time. Publishable's `WindowTransitionJob` sends when it is due. Publishing with no future time sends immediately, the same as Send now. `sent_at` is set when sending starts, so a reschedule, a late job, or unpublishing before the time cannot send twice.
- Once `sent_at` is set, Publishable update and transition writes are refused (pages, JSON, and API). Edit redirects to the broadcasts list. Edit and Delete are hidden on the admin resource. Cancel and completing a send still run.
- The broadcast show page and the broadcasts table show that time and a Scheduled or Sent state with Flatpack components.
- Unpublish returns a scheduled broadcast to draft and does not send it.

### Changed

- The dummy asset path serves `application.css`, so engine layouts that link it no longer 500.
- The dummy app installs Recording Studio Accessible's access-request migrations, including `recording_studio_access_request_intents`.
- The broadcasts screen subtitle stays "Product updates sent by email". An empty list uses Admin's normal empty table.
- Show-page actions use Flatpack buttons that wrap: Send now stands alone, the other actions are the same button shape, and Delete is a separate danger button. Details stack as a key/value list on a narrow screen, with Flatpack's own one-pixel list divider between rows. The status badge sits beside the same page title the index uses. The message field uses Flatpack's control radius. The dummy's rounded theme keeps a textarea at the default radius, so the message is not a pill.
- A published event sends only when Publishable's window job fires (`source` `scheduled`), the broadcast is still scheduled, and the job's `publish_at` still matches `scheduled_at`. Publishing a draft through Publishable does not send, and Send now enqueues delivery once. When that clock no longer matches, the broadcast returns to draft instead of staying scheduled. Scheduling a broadcast that is already live keeps it scheduled. `launch` raises `ArgumentError` when no actor is given.
- Broadcasts owns the send time. An outside Publishable edit of a scheduled broadcast (the time moved, published now, or unpublished) returns it to draft, records that editor, and cancels the pending send. The show page says who changed it, or "the system" when there is no actor. The broadcast does not follow the new time. Publishable's write and that draft are not one transaction. If the draft fails, it is logged and the retry is enqueued after the host transaction commits, with the editor's id and type. The job retries five times and discards an invalid transition. A live unpublish or revise still returns a scheduled broadcast to draft.
- A host that mounts Publishable serves `/published/:uuid/:slug` for a sent broadcast as an empty page. The broadcast stays published so the send is not withdrawn.
- Scheduling stores who scheduled it. The send re-checks that person can still send. Cancel also unpublishes the Publishable record. Schedule and unpublish each write the publishable clock and the broadcast status in one transaction. An unpublish or revise of a live Publishable record returns a scheduled broadcast to draft.
- Notifications is pinned to `v0.11.0` and Flatpack to `v0.1.254` (`flat_pack ~> 0.1.254`). Admin is pinned to tag `v2.4.0` (the merge of RecordingStudio_admin #31).

## [0.1.0]

### Added

- Broadcasts section, screen, and detail pages in Recording Studio Admin, built with Flatpack components.
- `RecordingStudioBroadcasts::Broadcast` recordable with draft, scheduled, sending, completed, and cancelled statuses, changed through `revise`.
- Host-registered audience filters combined with AND, plus `preview` counts for matching, eligible, and excluded people.
- `launch`, `schedule`, `cancel`, and `test_send` commands. Sending snapshots the audience into `recording_studio_broadcast_recipients` and delivers in batches through `recording_studio_notifications` email. Unsubscribe links and `List-Unsubscribe` headers come from `recording_studio_notifications_email` 0.3.15.
- Install generator for the initializer and the admin section key, and a migrations generator.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_broadcasts/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_broadcasts/compare/v0.6.0...v0.7.0
