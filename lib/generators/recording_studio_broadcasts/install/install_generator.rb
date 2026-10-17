# frozen_string_literal: true

require "rails/generators"

module RecordingStudioBroadcasts
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs the RecordingStudioBroadcasts initializer"

      def copy_initializer
        template "recording_studio_broadcasts_initializer.rb", "config/initializers/recording_studio_broadcasts.rb"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
