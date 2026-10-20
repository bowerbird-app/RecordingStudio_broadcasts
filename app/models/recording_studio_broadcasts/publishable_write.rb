# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Broadcasts calls Publishable itself when it sets the send clock.
  # Those writes must not look like an outside edit. The marker lists the
  # recording ids this call owns, so a write to a different broadcast still locks.
  module PublishableWrite
    KEY = :recording_studio_broadcasts_own_publishable_write

    module_function

    def own_write(*recordings)
      previous = Array(ActiveSupport::IsolatedExecutionState[KEY])
      ActiveSupport::IsolatedExecutionState[KEY] = previous + recordings.flatten.map(&:id)
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[KEY] = previous
    end

    def own_publishable_write?(recording)
      id = recording.respond_to?(:id) ? recording.id : recording
      id.present? && Array(ActiveSupport::IsolatedExecutionState[KEY]).include?(id)
    end
  end
end
