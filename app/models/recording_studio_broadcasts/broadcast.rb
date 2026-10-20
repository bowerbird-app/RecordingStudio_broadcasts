# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Broadcast < ActiveRecord::Base
    self.table_name = "recording_studio_broadcasts"
    self.record_timestamps = false

    recording_studio_recordable label: "Broadcast",
                                root: false,
                                allowed_parent_types: [RecordingStudioBroadcasts.configuration.admin_root_type]

    # publish_at on the publishable child is when this broadcast is sent.
    # seo stays off: a broadcast is an email, not a public page.
    include RecordingStudio::Capabilities::Publishable.to(schedule: true, seo: false)

    validates :title, :subject, presence: true
    validates :status, inclusion: { in: Campaign::TRANSITIONS.keys }
    validates :scheduled_at, presence: true, if: -> { status == "scheduled" }
  end
end
