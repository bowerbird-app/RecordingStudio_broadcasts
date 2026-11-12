# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Send
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        RecordingStudioBroadcasts.publish_now(recording, actor: @context.actor)
        recording.reload
      rescue RecordingStudioBroadcasts::InvalidTransition => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
