# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Cancel
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        RecordingStudioBroadcasts.cancel(recording, actor: @context.actor)
        recording.reload
      rescue RecordingStudioBroadcasts::InvalidTransition, ActiveRecord::RecordInvalid => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
