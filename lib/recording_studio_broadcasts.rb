# frozen_string_literal: true

require "recording_studio"
require "recording_studio_broadcasts/version"
require "recording_studio_broadcasts/configuration"
require "recording_studio_broadcasts/engine"

module RecordingStudioBroadcasts
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
