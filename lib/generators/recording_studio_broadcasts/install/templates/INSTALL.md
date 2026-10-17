RecordingStudioBroadcasts install complete.

Next steps:

1. Point `config.recipients` in config/initializers/recording_studio_broadcasts.rb at the people broadcasts can reach.
2. Set `config.from` in config/initializers/recording_studio_notifications_email.rb.
3. Copy the migrations with `bin/rails generate recording_studio_broadcasts:migrations`.
4. Apply them with `bin/rails db:migrate`.
