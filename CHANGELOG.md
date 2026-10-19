# Changelog

## [0.2.0]

### Added

- A broadcast's send time is Recording Studio Publishable's `publish_at` (git tag `v0.9.1`). Scheduling stores that time. Publishable's `WindowTransitionJob` sends when it is due. Publishing with no future time sends immediately, the same as Send now. `sent_at` is set when sending starts, so a reschedule, a late job, or unpublishing before the time cannot send twice.
- The broadcast show page and the broadcasts table show that time and a Scheduled or Sent state with Flatpack components.
- Unpublish returns a scheduled broadcast to draft and does not send it.

### Changed

- The dummy Devise sign-up, forgot-password, edit, and reset pages use Flatpack components in the same centered card as sign-in. A wrong password shows the Devise alert in a Flatpack alert.
- The dummy asset path serves `application.css`, so engine layouts that link it no longer 500.
- The dummy app installs Recording Studio Accessible's access-request migrations and Action Mailbox's migrations, including `recording_studio_access_request_intents` and `action_mailbox_inbound_emails`.
- An empty broadcasts list renders Flatpack's empty state from the broadcasts view when there are no broadcasts.
- Draft actions use a Flatpack button group so Delete is not squeezed into a four-column grid cell.
- A published event sends only when Publishable's window job fires (`source` `scheduled`) and the broadcast is still scheduled. Publishing a draft through Publishable does not send, and Send now enqueues delivery once.
- Scheduling stores who scheduled it and the send uses that person. Cancel also unpublishes the Publishable record. Schedule and unpublish each write the publishable clock and the broadcast status in one transaction.
- Notifications is pinned to `v0.11.0` and Flatpack to `v0.1.254` (`flat_pack ~> 0.1.254`). Admin is pinned to tag `v2.4.0` (the merge of RecordingStudio_admin #31).

## [0.1.0]

### Added

- Broadcasts section, screen, and detail pages in Recording Studio Admin, built with Flatpack components.
- `RecordingStudioBroadcasts::Broadcast` recordable with draft, scheduled, sending, completed, and cancelled statuses, changed through `revise`.
- Host-registered audience filters combined with AND, plus `preview` counts for matching, eligible, and excluded people.
- `launch`, `schedule`, `cancel`, and `test_send` commands. Sending snapshots the audience into `recording_studio_broadcast_recipients` and delivers in batches through `recording_studio_notifications` email. Unsubscribe links and `List-Unsubscribe` headers come from `recording_studio_notifications_email` 0.3.15.
- Install generator for the initializer and the admin section key, and a migrations generator.
