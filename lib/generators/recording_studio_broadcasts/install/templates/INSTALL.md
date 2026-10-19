RecordingStudioBroadcasts install complete.

Next steps:

1. Point `config.recipients` in config/initializers/recording_studio_broadcasts.rb at the people broadcasts can reach.
2. Set `config.from` in config/initializers/recording_studio_notifications_email.rb.
3. Install Publishable and copy its migrations with `bin/rails generate recording_studio_publishable:migrations`. Broadcasts reads the send time from that gem.
4. Copy the Broadcasts migrations with `bin/rails generate recording_studio_broadcasts:migrations`.
5. Apply them with `bin/rails db:migrate`.
6. If your admin root lists its sections, make sure the block includes `section :broadcasts`.
