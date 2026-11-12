# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Update
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        @context.access_grant.authorize!(recording: recording, role: :admin)
        RecordingStudioBroadcasts::Campaign.update(recording, actor: @context.actor, **Attributes.content(@context))

        {
          json: Serialize.recording(recording.reload, context: @context),
          status: :ok
        }
      rescue ActiveRecord::RecordInvalid => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
