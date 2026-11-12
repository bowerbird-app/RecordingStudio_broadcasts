# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Preview
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = CampaignRecording.find!(@context)
        RecordingStudioBroadcasts.preview(recording)
      end
    end
  end
end
