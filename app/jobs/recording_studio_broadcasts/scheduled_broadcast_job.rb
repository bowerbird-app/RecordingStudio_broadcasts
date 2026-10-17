# frozen_string_literal: true

module RecordingStudioBroadcasts
  class ScheduledBroadcastJob < ActiveJob::Base
    queue_as :default

    def perform(recording, scheduled_at, actor = nil)
      Campaign.launch(recording, actor:, scheduled_at:)
    end
  end
end
