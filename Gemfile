# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_broadcasts.gemspec
gemspec

# Recording Studio gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.251"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.20.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.3.3"
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.3.1"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.10.0"
gem "recording_studio_notifications_email", github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.3.15"
gem "recording_studio_root_switchable", github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.9.4"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
