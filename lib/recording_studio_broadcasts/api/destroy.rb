# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Destroy
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        @context.access_grant.authorize!(recording: recording, role: :admin)
        RecordingStudioBroadcasts::Campaign.destroy(recording, actor: @context.actor)

        { json: {}, status: :no_content }
      end
    end
  end
end
