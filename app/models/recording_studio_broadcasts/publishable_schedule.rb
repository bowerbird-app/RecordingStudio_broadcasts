# frozen_string_literal: true

module RecordingStudioBroadcasts
  # The send clock is Publishable's publish_at. Update and Transition enqueue
  # WindowTransitionJob at that time; this module does not schedule a second job.
  module PublishableSchedule
    module_function

    def schedule_at(recording, at:, actor:)
      PublishableWrite.own_write(recording) do
        unwrap!(RecordingStudioPublishable::Services::Publishables::Update.call(
                  parent_recording: recording,
                  actor:,
                  attributes: attributes_for(at)
                ))
      end
    end

    def publish_now(recording, actor:)
      PublishableWrite.own_write(recording) do
        unwrap!(RecordingStudioPublishable::Services::Publishables::Transition.call(
                  parent_recording: recording,
                  transition: "publish",
                  actor:
                ))
      end
    end

    def unpublish(recording, actor:)
      PublishableWrite.own_write(recording) do
        unwrap!(RecordingStudioPublishable::Services::Publishables::Transition.call(
                  parent_recording: recording,
                  transition: "unpublish",
                  actor:
                ))
      end
    end

    def attributes_for(at)
      zone = Time.zone
      {
        status: "scheduled",
        publish_at: at.utc.iso8601,
        time_zone: zone.tzinfo.name
      }
    end

    def unwrap!(result)
      return result.value if result.success?

      error = result.error
      raise Error, (error.respond_to?(:message) ? error.message : error.to_s)
    end
    private_class_method :attributes_for, :unwrap!
  end
end
