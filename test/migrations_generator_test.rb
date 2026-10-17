# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "generators/recording_studio_broadcasts/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_copies_each_migration_once_with_distinct_increasing_versions
    Dir.mktmpdir do |dir|
      2.times { capture_io { RecordingStudioBroadcasts::Generators::MigrationsGenerator.start([], destination_root: dir) } }

      copied = Dir[File.join(dir, "db/migrate/*.rb")].map { |path| File.basename(path) }.sort
      versions = copied.map { |name| name[/\A\d+/] }
      names = copied.map { |name| name.sub(/\A\d+_/, "") }

      assert_equal %w[create_recording_studio_broadcasts.rb create_recording_studio_broadcast_recipients.rb], names
      assert_equal versions.uniq, versions
    end
  end
end
