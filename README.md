# Recording Studio Broadcasts

`recording_studio_broadcasts` adds a **Broadcasts** section to Recording Studio Admin. An admin writes a product update, picks who gets it with filters the host app defines, sees how many people it will reach, and sends it by email now or at a set time.

Each broadcast is a Recording under the admin root, so edits and status changes keep Recording Studio history. Sending goes through `recording_studio_notifications` and its email channel, so notification preferences, idempotency, and address suppressions apply to every message.

## Install

These gems are not on RubyGems. Pin them from GitHub in the host `Gemfile`:

```ruby
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.20.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.3.3"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.10.0"
gem "recording_studio_notifications_email", github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.3.14"
gem "recording_studio_broadcasts", github: "bowerbird-app/RecordingStudio_broadcasts", tag: "v0.1.0"
```

Install Admin, Notifications, and the email channel first, following their READMEs. Then:

```bash
bin/rails generate recording_studio_broadcasts:install
bin/rails generate recording_studio_broadcasts:migrations
bin/rails db:migrate
```

The install generator writes `config/initializers/recording_studio_broadcasts.rb`. If your admin root model lists its sections with `recording_studio_admin_sections`, the generator adds `section :broadcasts` to that block. Admin 2.3 cannot add a section to a host list on its own. If you add the line by hand, it is one line:

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
  config.batch_size = 100
  config.admin_root_type = "AdminRoot"
  config.recipients(
    relation: -> { User.all },
    email: :email,
    name: ->(user) { user.email }
  )
end

RecordingStudioBroadcasts.register_filter(:registered_after, label: "Joined after", input: :date) do |scope, value|
  scope.where(users: { created_at: Time.zone.parse(value.to_s).. })
end
```

`relation` returns the people a broadcast can reach. `email` and `name` take a method name or a proc. Each filter gets the current scope and the admin's value and returns a narrower scope. Filters combine with AND. A blank value skips its filter. Registering the same key again replaces it, so reloading code is safe. A saved broadcast whose filter key is no longer registered matches nobody. It never widens to everyone.

Broadcasts counts people by `email`, but the email channel looks the address up on its own. It uses `recipient.email` by default. If your address lives elsewhere, register the same lookup with the email channel so both agree:

```ruby
RecordingStudioNotificationsEmail.config.recipients.register(User) { |user| user.contact_email }
```

## Send

The Broadcasts screen lists every broadcast. The detail page shows who gets it (Matching, Ready, Left out), the filters, and how sending is going. View access can open both. Sending, scheduling, cancelling, editing, test sends, and deleting need admin access. Only a draft can be deleted. A sent or cancelled broadcast stays as a record.

Each admin gets one test email per broadcast. The test uses a fixed idempotency key, so asking again sends nothing and the page says so.

The same commands are available in Ruby:

```ruby
RecordingStudioBroadcasts.preview(recording)            # => { matching:, eligible:, excluded: }
RecordingStudioBroadcasts.test_send(recording, actor: user)
RecordingStudioBroadcasts.launch(recording, actor: user)
RecordingStudioBroadcasts.schedule(recording, at: 1.day.from_now, actor: user)
RecordingStudioBroadcasts.cancel(recording, actor: user)
```

Launch copies the ready audience into a recipients table, then a job sends in batches of `batch_size`. Each person gets one email per broadcast, even if the job retries. People who turned off product updates, or whose address is suppressed, are skipped and counted.

## The List-Unsubscribe gap

Every email ends with an `Unsubscribe:` link from `RecordingStudioNotifications.unsubscribe_url`. Messages do not carry `List-Unsubscribe` or `List-Unsubscribe-Post` headers. Notifications can build those headers with `list_unsubscribe_headers`, but the email channel's mailer sets only its own headers and `deliver` takes no extra ones. Adding the headers needs a change in `recording_studio_notifications_email`, not a custom mailer here.

## Development

```bash
bundle install
bundle exec rake test:all
bundle exec rubocop
```

The dummy app in `test/dummy` signs in as `admin@admin.com` / `Password` (admin) or `viewer@example.com` / `Password` (view only).

## License

MIT
