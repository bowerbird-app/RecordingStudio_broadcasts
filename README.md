# Recording Studio Broadcasts

`recording_studio_broadcasts` adds a **Broadcasts** section to Recording Studio Admin. An admin writes a product update, picks who gets it with filters the host app defines, sees how many people it will reach, and sends it by email now or at a set time.

Each broadcast is a Recording under the admin root, so edits and status changes keep Recording Studio history. Sending goes through `recording_studio_notifications` and its email channel, so notification preferences, idempotency, and address suppressions apply to every message.

## Install

These gems are not on RubyGems. Pin them from GitHub in the host `Gemfile`:

```ruby
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.12.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.1"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.9.1"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.16.0"
gem "recording_studio_notifications_email", github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.5.2"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.22.0"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.13.0"
gem "recording_studio_broadcasts", github: "bowerbird-app/RecordingStudio_broadcasts", tag: "v0.2.1"
```

Install Admin, Notifications, the email channel, and Publishable first, following their READMEs. Publishable's recordable includes Attachable, so install that gem too. Then:

```bash
bin/rails generate recording_studio_publishable:install
bin/rails generate recording_studio_publishable:migrations
bin/rails generate recording_studio_broadcasts:install
bin/rails generate recording_studio_broadcasts:migrations
bin/rails db:migrate
```

The install generator writes `config/initializers/recording_studio_broadcasts.rb`. Add these recordable types if your initializer lists them by hand. Broadcasts registers them after your initializers load:

```ruby
"RecordingStudioBroadcasts::Broadcast",
"RecordingStudioPublishable::Publishable",
"RecordingStudioAttachable::Attachment"
```

If your admin root model lists its sections with `recording_studio_admin_sections`, the generator adds `section :broadcasts` to that block. Admin 2.3 cannot add a section to a host list on its own. If you add the line by hand, it is one line:

```ruby
recording_studio_admin_sections do
  section :root
  section :broadcasts
end
```

Set the sender on the email channel. Broadcasts does not keep its own copy:

```ruby
RecordingStudioNotificationsEmail.configure do |config|
  config.from = "Product updates <updates@example.com>"
end
```

## Configure recipients and filters

```ruby
RecordingStudioBroadcasts.configure do |config|
  config.admin_root_type = "AdminRoot"
  config.recipients(
    relation: -> { User.all }
  )
end

RecordingStudioBroadcasts.register_filter(:registered_after, label: "Joined after", input: :date) do |scope, value|
  scope.where(users: { created_at: Time.zone.parse(value.to_s).. })
end
```

`relation` returns the people a broadcast can reach. Addresses come from the email channel. It uses `recipient.email` by default. If an address lives elsewhere, register that lookup once on the email channel so preview and send agree:

```ruby
RecordingStudioNotificationsEmail.config.recipients.register("User", ->(user) { user.contact_email })
```

Each filter gets the current scope and the admin's value and returns a narrower scope. Filters combine with AND. A blank value skips its filter. Registering the same key again replaces it, so reloading code is safe. A saved broadcast whose filter key is no longer registered matches nobody. It never widens to everyone.

## Send

The Broadcasts screen lists every broadcast. The detail page shows who gets it (Matching, Ready, Left out), the filters, and how sending is going. View access can open both. Sending, scheduling, cancelling, editing, test sends, and deleting need admin access. Only a draft can be deleted. A sent or cancelled broadcast stays as a record.

Once `sent_at` is set, the broadcast is locked. Opening edit redirects to the broadcasts list with an alert. Edit and Delete on the admin resource are hidden and refused. Publishable cannot update that broadcast or run publish, schedule, unpublish, or draft, including SEO and social fields. That refusal is the same for Publishable's pages, its JSON responses, and its API. Cancel and completing a send still work: those writes are marked as Broadcasts' own Publishable write for that recording. A draft or a scheduled broadcast can still be edited. Direct `update!` or `update_columns`, revising the publishable child, and trash bypass this lock.

Each admin gets one test email per broadcast. The test uses a fixed idempotency key, so asking again sends nothing and the page says so.

The same commands are available in Ruby:

```ruby
RecordingStudioBroadcasts.preview(recording)            # => { matching:, eligible:, excluded: }
RecordingStudioBroadcasts.test_send(recording, actor: user)
RecordingStudioBroadcasts.launch(recording, actor: user)
RecordingStudioBroadcasts.publish_now(recording, actor: user)
RecordingStudioBroadcasts.schedule(recording, at: 1.day.from_now, actor: user)
RecordingStudioBroadcasts.unpublish(recording, actor: user)
RecordingStudioBroadcasts.cancel(recording, actor: user)
```

`schedule` stores the send time as Publishable's `publish_at`. Publishable enqueues `WindowTransitionJob` for that time, and the published event sends the broadcast. A publish time that is already due sends immediately. Unpublishing before that time returns the broadcast to draft and sends nothing. `sent_at` is set when sending starts, so a second publish, a reschedule, or a job from an older clock cannot send twice.

Launch copies the ready audience into a recipients table, then enqueues `RecordingStudioNotifications.notify_fan_out` for that snapshot. Notifications writes the rows in chunks of 1,000. One idempotency key per broadcast means a retry does not email the same person again. Someone who turns product updates off after launch is skipped and counted. A suppressed address is skipped when the email channel refuses it, and counted. Cancel marks people who are still waiting as skipped, and later chunks leave them out. A chunk already loaded, up to 1,000 people, can still be emailed. The detail page counts Waiting, Sending, Sent, Skipped, and Failed from the snapshot rows. A test send is one synchronous notification, with its own idempotency key. The unsubscribe link and `List-Unsubscribe` headers come from the email channel.

## Development

```bash
bundle install
bundle exec rake test:all
bundle exec rubocop
```

The dummy app in `test/dummy` signs in as `admin@admin.com` / `Password` (admin) or `viewer@example.com` / `Password` (view only).

## License

MIT
