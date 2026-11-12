# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Show
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        @context.access_grant.authorize!(recording: recording, role: :view)

        {
          json: Serialize.recording(recording, context: @context),
          status: :ok
        }
      end
    end
  end
end
