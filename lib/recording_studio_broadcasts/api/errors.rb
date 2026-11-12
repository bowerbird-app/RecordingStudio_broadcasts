# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Errors
      module_function

      def with_domain_errors
        yield
      rescue InvalidTransition => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
