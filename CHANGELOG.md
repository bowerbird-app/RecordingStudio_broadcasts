# Changelog

## [0.2.0]

### Added

- A broadcast's send time is Recording Studio Publishable's `publish_at` (git tag `v0.9.1`). Scheduling stores that time. Publishable's `WindowTransitionJob` sends when it is due. Publishing with no future time sends immediately, the same as Send now. `sent_at` is set when sending starts, so a reschedule, a late job, or unpublishing before the time cannot send twice.
- The broadcast show page and the broadcasts table show that time and a Scheduled or Sent state with Flatpack components.
- Unpublish returns a scheduled broadcast to draft and does not send it.

### Changed

- The dummy asset path serves `application.css`, so engine layouts that link it no longer 500.
- The dummy app installs Recording Studio Accessible's access-request migrations, including `recording_studio_access_request_intents`.
- The broadcasts screen subtitle stays "Product updates sent by email". An empty list uses Admin's normal empty table.
- Show-page actions use Flatpack buttons that wrap: Send now stands alone, the other actions are the same button shape, and Delete is a separate danger button. Details stack as a key/value list on a narrow screen, with Flatpack's own one-pixel list divider between rows. The status badge sits beside the same page title the index uses. The message field uses Flatpack's control radius. The dummy's rounded theme keeps a textarea at the default radius, so the message is not a pill.
- A published event sends only when Publishable's window job fires (`source` `scheduled`), the broadcast is still scheduled, and the job's `publish_at` still matches `scheduled_at`. Publishing a draft through Publishable does not send, and Send now enqueues delivery once. When that clock no longer matches, the broadcast returns to draft instead of staying scheduled. Scheduling a broadcast that is already live keeps it scheduled. `launch` raises `ArgumentError` when no actor is given.
- Broadcasts owns the send time. An outside Publishable edit of a scheduled broadcast (the time moved, published now, or unpublished) returns it to draft, records that editor, and cancels the pending send. The show page says who changed it, or "the system" when there is no actor. The broadcast does not follow the new time. Publishable's write and that draft are not one transaction. If the draft fails, it is logged and retried later. A live unpublish or revise still returns a scheduled broadcast to draft.
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
