# frozen_string_literal: true

require_relative "lib/recording_studio_broadcasts/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_broadcasts"
  spec.version     = RecordingStudioBroadcasts::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_broadcasts"
  spec.summary     = "Site-wide email broadcasts for Recording Studio admins"
  spec.description = "Write a product update in Recording Studio Admin, pick who gets it with host-defined filters, " \
                     "preview the audience, and send it by email through Recording Studio Notifications."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_broadcasts"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_broadcasts/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack", "~> 0.1.207"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.7"
  spec.add_dependency "recording_studio_accessible", "~> 0.18"
  spec.add_dependency "recording_studio_admin", ">= 2.3", "< 2.4"
  spec.add_dependency "recording_studio_notifications", ">= 0.10.0", "< 0.11"
  spec.add_dependency "recording_studio_notifications_email", ">= 0.3.14", "< 0.4"
end
