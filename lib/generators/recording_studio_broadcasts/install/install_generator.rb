# frozen_string_literal: true

require "rails/generators"

module RecordingStudioBroadcasts
  module Generators
    class InstallGenerator < Rails::Generators::Base
      SECTIONS_BLOCK = /^([ \t]*)recording_studio_admin_sections do[ \t]*\n/
      LISTED = /^\s*section :broadcasts\b/

      source_root File.expand_path("templates", __dir__)

      desc "Installs the RecordingStudioBroadcasts initializer and admin section"

      class_option :admin_root_type, type: :string, default: "AdminRoot",
                                     desc: "Class name of the admin root recordable"

      def copy_initializer
        template "recording_studio_broadcasts_initializer.rb", "config/initializers/recording_studio_broadcasts.rb"
      end

      def add_admin_section
        path = "app/models/#{options[:admin_root_type].underscore}.rb"
        source = File.exist?(File.join(destination_root, path)) ? File.read(File.join(destination_root, path)) : ""
        block = source.match(SECTIONS_BLOCK)
        return say_status(:skip, "#{path} has no recording_studio_admin_sections block", :yellow) unless block
        return say_status(:identical, "#{path} already lists :broadcasts", :blue) if source.match?(LISTED)

        inject_into_file path, "#{block[1]}  section :broadcasts\n", after: SECTIONS_BLOCK
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
