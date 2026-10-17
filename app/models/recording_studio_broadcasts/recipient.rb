# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Recipient < ActiveRecord::Base
    STATUSES = %w[pending sending sent skipped failed].freeze
    STATUS_LABELS = {
      "pending" => "Waiting",
      "sending" => "Sending",
      "sent" => "Sent",
      "skipped" => "Skipped",
      "failed" => "Failed"
    }.freeze
    SKIP_REASONS = %w[preference suppressed cancelled].freeze
    STALE_CLAIM_AFTER = 15.minutes

    self.table_name = "recording_studio_broadcast_recipients"

    belongs_to :recording, class_name: "RecordingStudio::Recording"
    belongs_to :recipient, polymorphic: true

    # A worker that crashed before notify leaves its rows sending with no notification, so they become claimable again.
    scope :claimable, lambda {
      where(status: "pending").or(where(status: "sending", notification_id: nil, claimed_at: ...STALE_CLAIM_AFTER.ago))
    }

    validates :status, inclusion: { in: STATUSES }
    validates :skip_reason, inclusion: { in: SKIP_REASONS }, allow_nil: true
  end
end
