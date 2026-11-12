# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class TestSend
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        RecordingStudioBroadcasts.test_send(recording, actor: @context.actor)
        recording.reload
      end
    end
  end
end
