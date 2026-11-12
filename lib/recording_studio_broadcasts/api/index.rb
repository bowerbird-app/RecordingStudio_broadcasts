# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Index
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        parent = CampaignRecording.parent!(@context, role: :view)
        recordings = RecordingStudioBroadcasts::Campaign.recordings(parent)
        {
          json: recordings.map { |recording| Serialize.recording(recording, context: @context) },
          status: :ok
        }
      end
    end
  end
end
