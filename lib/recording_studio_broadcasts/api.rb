# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    OPERATIONS_API = :operations
    RECORDABLE_TYPE = "RecordingStudioBroadcasts::Broadcast"
    CAPABILITY = :broadcasts
    CAPABILITY_ACTIONS = %i[send schedule unpublish cancel test_send preview].freeze
    CRUD_ACTIONS = %i[index show create update destroy].freeze

    class << self
      def register!
        return unless recording_studio_api_available?

        RecordingStudio.enable_capability(CAPABILITY, on: RECORDABLE_TYPE)
        require_relative "api/registration"
        Registration.register!
        true
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_recordable_type_api)
      end

      def content_keys
        RecordingStudioBroadcasts::Campaign::CONTENT
      end

      def output_keys
        content_keys + %i[status scheduled_at sent_at]
      end
    end
  end
end
