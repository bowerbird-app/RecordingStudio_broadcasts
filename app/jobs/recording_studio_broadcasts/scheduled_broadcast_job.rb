# frozen_string_literal: true

module RecordingStudioBroadcasts
  class ScheduledBroadcastJob < ActiveJob::Base
    queue_as :default

    # Schedule no longer enqueues this job. Publishable's WindowTransitionJob
    # fires at publish_at. This remains so a job queued before that change can
    # still launch, and only while its clock matches and sent_at is empty.
    def perform(recording, scheduled_at, actor = nil)
      Campaign.launch(recording, actor:, scheduled_at:)
    end
  end
end
