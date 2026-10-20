# frozen_string_literal: true

require "recording_studio"
require "recording_studio_notifications"
require "recording_studio_notifications_email"
require "recording_studio_admin"
# Publishable's recordable includes Attachable at load time, so that capability
# has to be registered before the publishable model is eager loaded.
require "recording_studio_attachable"
require "recording_studio_publishable"
require "recording_studio_broadcasts/version"
require "recording_studio_broadcasts/configuration"
require "recording_studio_broadcasts/filter_registry"
require "recording_studio_broadcasts/engine"

module RecordingStudioBroadcasts
  NOTIFICATION_TYPE = :product_update

  class Error < StandardError; end
  class InvalidTransition < Error; end

  class << self
    attr_accessor :admin_routes_appended

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

    def launch(recording, actor:)
      Campaign.launch(recording, actor:)
    end

    def schedule(recording, at:, actor:)
      Campaign.schedule(recording, at:, actor:)
    end

    def publish_now(recording, actor:)
      Campaign.publish_now(recording, actor:)
    end

    def unpublish(recording, actor:)
      Campaign.unpublish(recording, actor:)
    end

    def cancel(recording, actor:)
      Campaign.cancel(recording, actor:)
    end

    def test_send(recording, actor:)
      Delivery.test_send(recording, actor:)
    end

    def subscribe_publishable_writes!
      RecordingStudioPublishable.subscribe(:published) { |event| Campaign.deliver_published(event.payload) }
      # Update runs this in-process, so a future send time is caught before any window job.
      RecordingStudioPublishable.configuration.hooks.after_service do |service_class, result|
        Campaign.note_external_publishable_write(service_class, result)
      end
      # A future schedule is not live, so these do not fire for that edit.
      %i[unpublished revised].each do |name|
        RecordingStudioPublishable.subscribe(name) do |event|
          Campaign.withdraw_after_publishable_change(event.payload)
        end
      end
      SentPublishableLock.install!
    end

    def install_publish_delivery!
      return if @publish_delivery_installed

      @publish_delivery_installed = true
      subscribe_publishable_writes!
    end
  end
end
