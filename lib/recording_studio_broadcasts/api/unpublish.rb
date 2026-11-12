# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Unpublish
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        @context.access_grant.authorize!(recording: recording, role: :admin)
        RecordingStudioBroadcasts.unpublish(recording, actor: @context.actor)

        {
          json: Serialize.recording(recording.reload, context: @context),
          status: :ok
        }
      rescue RecordingStudioBroadcasts::InvalidTransition => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
