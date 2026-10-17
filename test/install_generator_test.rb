# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "generators/recording_studio_broadcasts/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  def test_writes_the_initializer_and_prints_next_steps
    Dir.mktmpdir do |dir|
      output, = capture_io { RecordingStudioBroadcasts::Generators::InstallGenerator.start([], destination_root: dir) }

      initializer = File.read(File.join(dir, "config/initializers/recording_studio_broadcasts.rb"))
      assert_includes initializer, "RecordingStudioBroadcasts.configure do |config|"
      assert_includes initializer, "config.recipients("
      assert_includes initializer, "# RecordingStudioBroadcasts.register_filter(:registered_after"
      refute_includes initializer, "config.from"
      assert_includes output, "bin/rails generate recording_studio_broadcasts:migrations"
      assert_includes output, "recording_studio_notifications_email.rb"
    end
  end
end
