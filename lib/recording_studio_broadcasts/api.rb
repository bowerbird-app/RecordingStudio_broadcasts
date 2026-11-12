# frozen_string_literal: true

require_relative "api/closed"
require_relative "api/campaign_recording"
require_relative "api/attributes"
require_relative "api/serialize"
require_relative "api/index"
require_relative "api/show"
require_relative "api/create"
require_relative "api/update"
require_relative "api/destroy"
require_relative "api/send"
require_relative "api/schedule"
require_relative "api/unpublish"
require_relative "api/cancel"
require_relative "api/test_send"
require_relative "api/preview"
require_relative "api/registration"

module RecordingStudioBroadcasts
  module Api
    OPERATIONS_API = :operations
    RECORDABLE_TYPE = "RecordingStudioBroadcasts::Broadcast"
    WRITABLE_ATTRIBUTES = %i[title subject body filter_params].freeze

    class << self
      def register!
        return unless recording_studio_api_available?

        Registration.register!
        true
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_recordable_type_api)
      end
    end
  end
end
