# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Broadcast < ActiveRecord::Base
    self.table_name = "recording_studio_broadcasts"
    self.record_timestamps = false

    recording_studio_recordable label: "Broadcast",
                                root: false,
                                allowed_parent_types: [RecordingStudioBroadcasts.configuration.admin_root_type]

    validates :title, :subject, presence: true
    validates :status, inclusion: { in: Campaign::TRANSITIONS.keys }
  end
end
