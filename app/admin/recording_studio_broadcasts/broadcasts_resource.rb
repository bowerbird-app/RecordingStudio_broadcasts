# frozen_string_literal: true

module RecordingStudioBroadcasts
  class BroadcastsResource < RecordingStudioAdmin::Resource
    key "broadcasts"
    section "broadcasts"
    icon :megaphone
    title "Broadcasts"

    action :show, text: "Open", required_role: :view,
                  url: ->(recording, context) { context.routes.broadcast_path(recording) }
    action :create, text: "New broadcast", required_role: :admin,
                    url: ->(_recording, context) { context.routes.new_broadcast_path }
    action :update, text: "Edit", required_role: :admin,
                    visible_if: ->(recording) { unsent?(recording) },
                    url: ->(recording, context) { context.routes.edit_broadcast_path(recording) }
    action :delete, text: "Delete", method: :delete, required_role: :admin,
                    visible_if: ->(recording) { unsent?(recording) },
                    url: ->(recording, context) { context.routes.broadcast_path(recording) }
    action :send, text: "Send now", method: :post, required_role: :admin,
                  url: ->(recording, context) { context.routes.send_message_broadcast_path(recording) }
    action :schedule, text: "Schedule", method: :post, required_role: :admin,
                      url: ->(recording, context) { context.routes.schedule_broadcast_path(recording) }
    action :unpublish, text: "Unpublish", method: :post, required_role: :admin,
                       url: ->(recording, context) { context.routes.unpublish_broadcast_path(recording) }
    action :cancel, text: "Cancel", method: :post, required_role: :admin,
                    url: ->(recording, context) { context.routes.cancel_broadcast_path(recording) }
    action :test_send, text: "Send me a test", method: :post, required_role: :admin,
                       url: ->(recording, context) { context.routes.test_send_broadcast_path(recording) }

    def self.unsent?(recording)
      recording.present? && recording.recordable.sent_at.blank?
    end
  end
end
