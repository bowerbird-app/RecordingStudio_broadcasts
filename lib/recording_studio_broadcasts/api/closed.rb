# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    class Closed
      def self.call(_context)
        raise RecordingStudioApi::UnsupportedActionError, "Broadcasts are not on the public API"
      end
    end
  end
end
