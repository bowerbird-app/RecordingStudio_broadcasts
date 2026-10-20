# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioBroadcasts

    PUBLISHABLE_RECORDABLES = %w[
      RecordingStudioBroadcasts::Broadcast
      RecordingStudioPublishable::Publishable
      RecordingStudioAttachable::Attachment
    ].freeze

    # Host initializers replace recordable_types. Append after them so prepare
    # sees Publishable and the attachment child it includes.
    initializer "recording_studio_broadcasts.publishable_recordables", after: :load_config_initializers do
      configured = Array(RecordingStudio.configuration.recordable_types).map(&:to_s)
      RecordingStudio.configuration.recordable_types = (configured + PUBLISHABLE_RECORDABLES).uniq
    end

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
            post :unpublish
            post :cancel
            post :test_send
          end
        end
      end
    end

    config.to_prepare do
      RecordingStudioBroadcasts.install_publish_delivery!
      # A sent broadcast stays published so the withdrawal handler does not see :unpublished.
      # The public page is a blank template, so /published/:uuid/:slug reveals nothing.
      RecordingStudioPublishable.configuration.register_public_renderer(
        "RecordingStudioBroadcasts::Broadcast",
        controller: "recording_studio_broadcasts/blank_publications",
        action: :show,
        layout: "recording_studio_broadcasts/blank"
      )

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
