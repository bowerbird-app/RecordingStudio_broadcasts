# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Serialize
      module_function

      def attributes(broadcast)
        {
          title: broadcast.title,
          subject: broadcast.subject,
          body: broadcast.body,
          filter_params: broadcast.filter_params&.to_h,
          status: broadcast.status,
          scheduled_at: clock(broadcast.scheduled_at),
          sent_at: clock(broadcast.sent_at)
        }
      end

      def recording(recording, context)
        RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          recording,
          version: api_version(context),
          api: OPERATIONS_API
        )
      end

      def api_version(context)
        return context.api_version if context.respond_to?(:api_version) && context.api_version.present?

        RecordingStudioApi.default_api_version(api: OPERATIONS_API)
      end

      def clock(value)
        value&.utc&.iso8601
      end
    end
  end
end
