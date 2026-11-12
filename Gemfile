# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_broadcasts.gemspec
gemspec

# Recording Studio gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.341"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.1"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.9.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.22.0"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.2"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.3"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.2"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.14.8"
gem "recording_studio_notifications_email", github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.5.2"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.13.0"
gem "recording_studio_root_switchable", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.11.5"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.2"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.21.3"
  gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.1"
  gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v4.1.1"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
