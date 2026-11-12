# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Schedule
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        at = Attributes.scheduled_at(@context)
        RecordingStudioBroadcasts.schedule(recording, actor: @context.actor, at: at)
        recording.reload
      rescue RecordingStudioBroadcasts::InvalidTransition, ActiveRecord::RecordInvalid => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
