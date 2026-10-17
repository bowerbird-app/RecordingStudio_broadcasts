# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioBroadcasts

    initializer "recording_studio_broadcasts.recordable_type", after: :load_config_initializers do
      RecordingStudio.configuration.recordable_types =
        RecordingStudio.configuration.recordable_types | ["RecordingStudioBroadcasts::Broadcast"]
    end

    config.to_prepare do
      RecordingStudioNotifications.register_notification_type(
        RecordingStudioBroadcasts::NOTIFICATION_TYPE,
        label: "Product update",
        inbox: false,
        default_channels: [:email],
        available_channels: [:email],
        required_channels: [],
        scope: :global
      )
    end
  end
end
