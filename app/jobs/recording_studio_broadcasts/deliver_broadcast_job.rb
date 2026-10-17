# frozen_string_literal: true

module RecordingStudioBroadcasts
  class DeliverBroadcastJob < ActiveJob::Base
    queue_as :default

    def perform(recording, actor = nil)
      rows = Delivery.claim(recording)
      rows.each { |row| Delivery.deliver_one(row) }
      return unless recording.reload.recordable.status == "sending"
      return Campaign.complete!(recording, actor:) if Delivery.finished?(recording)

      # Rows another worker holds stay claimed until they finish or go stale, so poll instead of spinning.
      self.class.set(wait: rows.any? ? 0 : 1.minute).perform_later(recording, actor)
    end
  end
end
