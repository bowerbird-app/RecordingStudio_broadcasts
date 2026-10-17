# Changelog

## [0.1.0]

### Added

- Broadcasts section, screen, and detail pages in Recording Studio Admin, built with Flatpack components.
- `RecordingStudioBroadcasts::Broadcast` recordable with draft, scheduled, sending, completed, and cancelled statuses, changed through `revise`.
- Host-registered audience filters combined with AND, plus `preview` counts for matching, eligible, and excluded people.
- `launch`, `schedule`, `cancel`, and `test_send` commands. Sending snapshots the audience into `recording_studio_broadcast_recipients` and delivers in batches through `recording_studio_notifications` email. Unsubscribe links and `List-Unsubscribe` headers come from `recording_studio_notifications_email` 0.3.15.
- Install generator for the initializer and the admin section key, and a migrations generator.
