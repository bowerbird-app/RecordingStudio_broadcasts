# frozen_string_literal: true

module RecordingStudioBroadcasts
  class DeliverBroadcastJob < ActiveJob::Base
    queue_as :default

    def perform(recording, actor = nil)
      recording = recording.reload
      return unless recording.recordable.status == "sending"

      RecordingStudioNotifications.notify_fan_out(**fan_out(recording, actor))
    end

    private

    def fan_out(recording, actor)
      broadcast = recording.recordable
      {
        recipient_scope: Delivery::SCOPE, idempotency_key: Delivery.idempotency_key(recording),
        notification_type: NOTIFICATION_TYPE, title: broadcast.subject, body: broadcast.body,
        actor:, recording:, channels: [:email], inbox: false
      }
    end
  end
end
