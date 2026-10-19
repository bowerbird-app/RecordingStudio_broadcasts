# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Broadcasts calls Publishable itself when it sets the send clock.
  # Those writes must not look like an outside edit.
  module PublishableWrite
    KEY = :recording_studio_broadcasts_own_publishable_write

    module_function

    def own_write
      previous = ActiveSupport::IsolatedExecutionState[KEY]
      ActiveSupport::IsolatedExecutionState[KEY] = true
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[KEY] = previous
    end

    def own_publishable_write?
      ActiveSupport::IsolatedExecutionState[KEY] == true
    end
  end
end
