# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioBroadcasts
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("../../../../db/migrate", __dir__)

      desc "Copy RecordingStudioBroadcasts migrations to your application"

      def copy_migrations
        Dir[File.join(self.class.source_root, "*.rb")].each do |source|
          name = File.basename(source).sub(/\A\d+_/, "")
          if Dir[File.join(migrate_dir, "*_#{name}")].any?
            say_status :skip, name, :yellow
          else
            copy_file source, File.join("db/migrate", "#{self.class.next_migration_number(migrate_dir)}_#{name}")
          end
        end
      end

      private

      def migrate_dir
        File.join(destination_root, "db/migrate")
      end
    end
  end
end
