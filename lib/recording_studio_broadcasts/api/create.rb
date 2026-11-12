# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Create
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        persist
      rescue ActiveRecord::RecordInvalid => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end

      private

      def persist
        recording = RecordingStudioBroadcasts::Campaign.create(
          CampaignRecording.parent!(@context, role: :admin),
          actor: @context.actor,
          **Attributes.content(@context)
        )
        { json: Serialize.recording(recording, context: @context), status: :created }
      end
    end
  end
end
