# frozen_string_literal: true

require "recording_studio"
require "recording_studio_notifications"
require "recording_studio_notifications_email"
require "recording_studio_broadcasts/version"
require "recording_studio_broadcasts/configuration"
require "recording_studio_broadcasts/filter_registry"
require "recording_studio_broadcasts/engine"

module RecordingStudioBroadcasts
  NOTIFICATION_TYPE = :product_update

  class Error < StandardError; end
  class InvalidTransition < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def filters
      @filters ||= FilterRegistry.new
    end

    def register_filter(key, label:, input: :text, options: [], &)
      filters.register(key, label:, input:, options:, &)
    end

    def preview(recording)
      Audience.counts(recording.recordable.filter_params)
    end
  end
end
