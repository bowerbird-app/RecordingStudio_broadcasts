# frozen_string_literal: true

module RecordingStudioBroadcasts
  # A sent broadcast stays published, but nobody may edit that Publishable record
  # except Broadcasts itself. Publishable's Update and Transition both run through
  # around_service. Transition#perform calls Update.call, which starts its own
  # around_service, so a direct field edit and a nested transition write are the
  # same check. Refusing Transition before yielding means that nested Update never
  # starts. BaseService#failure is private, so the hook builds the public Result.
  module SentPublishableLock
    MESSAGE = "A sent broadcast cannot be changed."

    LOCKED_SERVICES = [
      RecordingStudioPublishable::Services::Publishables::Update,
      RecordingStudioPublishable::Services::Publishables::Transition
    ].freeze

    module_function

    def install!
      RecordingStudioPublishable.configuration.hooks.around_service do |service, inner|
        refusal_for(service) || inner.call
      end
    end

    def refusal_for(service)
      return unless LOCKED_SERVICES.include?(service.class)
      return if PublishableWrite.own_publishable_write?
      return unless sent_broadcast?(service.send(:parent_recording))

      failure
    end

    def sent_broadcast?(recording)
      return false if recording.nil?
      return false unless recording.recordable_type == Broadcast.name

      recording.reload.recordable.sent_at.present?
    end

    def failure
      RecordingStudio::Services::BaseService::Result.new(success: false, error: MESSAGE, errors: [MESSAGE])
    end
  end
end
