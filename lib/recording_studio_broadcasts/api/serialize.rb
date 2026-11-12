# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Serialize
      module_function

      def timestamp(value)
        value&.utc&.iso8601
      end

      BROADCAST = lambda do |broadcast, **|
        {
          title: broadcast.title,
          subject: broadcast.subject,
          body: broadcast.body,
          status: broadcast.status,
          scheduled_at: Serialize.timestamp(broadcast.scheduled_at),
          sent_at: Serialize.timestamp(broadcast.sent_at),
          filter_params: broadcast.filter_params.to_h
        }
      end

      PREVIEW = lambda do |counts, **|
        counts.respond_to?(:to_h) ? counts.to_h : counts
      end

      def recording(recording, context:)
        RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          recording,
          version: context.respond_to?(:api_version) ? context.api_version : nil,
          api: context.api_key
        )
      end
    end
  end
end
