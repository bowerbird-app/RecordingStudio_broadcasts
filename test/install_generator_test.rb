# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "generators/recording_studio_broadcasts/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  ADMIN_ROOT = <<~RUBY
    class AdminRoot < ApplicationRecord
      include RecordingStudioAdmin::AllowsAdminSections

      recording_studio_admin_sections do
        section :root
        section :admin_activity_logs
      end
    end
  RUBY

  def test_writes_the_initializer_and_prints_next_steps
    Dir.mktmpdir do |dir|
      output = run_generator(dir)

      initializer = File.read(File.join(dir, "config/initializers/recording_studio_broadcasts.rb"))
      assert_includes initializer, "RecordingStudioBroadcasts.configure do |config|"
      assert_includes initializer, 'config.admin_root_type = "AdminRoot"'
      assert_includes initializer, "config.recipients("
      assert_includes initializer, "# RecordingStudioBroadcasts.register_filter(:registered_after"
      refute_includes initializer, "config.from"
      assert_includes output, "bin/rails generate recording_studio_broadcasts:migrations"
      assert_includes output, "recording_studio_notifications_email.rb"
      assert_includes output, "app/models/admin_root.rb has no recording_studio_admin_sections block"
    end
  end

  def test_adds_the_broadcasts_section_once_and_keeps_the_other_keys
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      File.write(File.join(dir, "app/models/admin_root.rb"), ADMIN_ROOT)

      2.times { run_generator(dir) }

      model = File.read(File.join(dir, "app/models/admin_root.rb"))
      assert_includes model, "  recording_studio_admin_sections do\n    section :broadcasts\n    section :root\n"
      assert_includes model, "    section :admin_activity_logs\n"
      assert_equal 1, model.scan("section :broadcasts").size
    end
  end

  private

  def run_generator(dir)
    output, = capture_io { RecordingStudioBroadcasts::Generators::InstallGenerator.start([], destination_root: dir) }
    output
  end
end
