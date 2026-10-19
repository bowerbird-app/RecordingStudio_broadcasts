# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Broadcasts calls Publishable itself when it sets the send clock.
  # Those writes must not look like an outside edit.
  module PublishableWrite
    KEY = :recording_studio_broadcasts_own_publishable_write

    module_function

    def own_write
      previous = Thread.current[KEY]
      Thread.current[KEY] = true
      yield
    ensure
      Thread.current[KEY] = previous
    end

    def own_publishable_write?
      Thread.current[KEY] == true
    end
  end
end
