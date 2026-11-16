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
  AFTER_SERVICE_LATCH = :recording_studio_broadcasts_publishable_after_service
  LIFECYCLE_LISTENERS = {
    published: ->(event) { Campaign.deliver_published(event.payload) },
    unpublished: ->(event) { Campaign.withdraw_after_publishable_change(event.payload) },
    revised: ->(event) { Campaign.withdraw_after_publishable_change(event.payload) }
  }.freeze

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

    def install_publish_delivery!
      install_lifecycle_listeners!
      install_publishable_after_service!
      SentPublishableLock.install!
    end

    private

    def install_lifecycle_listeners!
      LIFECYCLE_LISTENERS.each_key { |name| install_lifecycle_listener(name) }
    end

    def install_lifecycle_listener(name)
      event_name = RecordingStudioPublishable::LifecycleNotifications.event_name_for(name)
      current = lifecycle_subscriptions[name]
      return if lifecycle_listener_active?(event_name, current)

      lifecycle_subscriptions[name] = RecordingStudioPublishable.subscribe(name) do |event|
        LIFECYCLE_LISTENERS.fetch(name).call(event)
      end
    end

    def lifecycle_listener_active?(event_name, subscription)
      subscription && ActiveSupport::Notifications.notifier.listeners_for(event_name).include?(subscription)
    end

    def lifecycle_subscriptions
      @lifecycle_subscriptions ||= {}
    end

    def install_publishable_after_service!
      hooks = RecordingStudio.configuration.hooks
      return if hooks.registered?(AFTER_SERVICE_LATCH)

      hooks.after_service { |service_class, result| note_publishable_write(service_class, result) }
      hooks.on(AFTER_SERVICE_LATCH) { true }
    end

    # Update runs in-process, so a future send time is caught before any window job.
    # Transition calls Update, which runs this hook itself.
    def note_publishable_write(service_class, result)
      return unless SentPublishableLock.locked_service?(service_class)

      Campaign.note_external_publishable_write(service_class, result)
    end
  end
end
