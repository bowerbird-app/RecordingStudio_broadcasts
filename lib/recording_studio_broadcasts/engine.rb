# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioBroadcasts

    config.to_prepare do
      RecordingStudio.register_recordable_type("RecordingStudioBroadcasts::Broadcast")
      RecordingStudioNotifications.register_notification_type(
        RecordingStudioBroadcasts::NOTIFICATION_TYPE,
        label: "Product update",
        inbox: false,
        default_channels: [:email],
        available_channels: [:email],
        required_channels: [],
        required_cadence: :individual,
        scope: :global
      )
    end
  end
end
