# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Recipient < ActiveRecord::Base
    STATUSES = %w[pending sending sent skipped failed].freeze

    self.table_name = "recording_studio_broadcast_recipients"

    belongs_to :recording, class_name: "RecordingStudio::Recording"
    belongs_to :recipient, polymorphic: true

    validates :status, inclusion: { in: STATUSES }
  end
end
