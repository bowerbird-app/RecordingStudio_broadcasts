# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioBroadcasts

    # Route set append blocks survive reloads, so drawing them from to_prepare would duplicate the routes.
    initializer "recording_studio_broadcasts.admin_routes" do
      next if RecordingStudioBroadcasts.admin_routes_appended

      RecordingStudioBroadcasts.admin_routes_appended = true
      RecordingStudioAdmin::Engine.routes.append do
        resources :broadcasts, controller: "/recording_studio_broadcasts/broadcasts",
                               only: %i[new create show edit update destroy] do
          member do
            post :send_message
            post :schedule
            post :cancel
            post :test_send
          end
        end
      end
    end

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
      RecordingStudioAdmin.register_section(RecordingStudioBroadcasts::BroadcastsSection)
      RecordingStudioAdmin.register_screen(RecordingStudioBroadcasts::BroadcastsScreen)
      RecordingStudioAdmin.register_resource(RecordingStudioBroadcasts::BroadcastsResource)
    end
  end
end
