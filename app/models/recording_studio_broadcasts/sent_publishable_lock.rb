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
        RecordingStudioBroadcasts::SentPublishableLock.refusal_for(service) || inner.call
      end
    end

    def refusal_for(service)
      return unless LOCKED_SERVICES.include?(service.class)

      parent_recording_id = parent_recording_id_for(service)
      return if PublishableWrite.own_publishable_write?(parent_recording_id)
      return unless sent?(parent_recording_id)

      failure
    end

    # service_args and parent_recording are private in Publishable v0.9.2.
    # Update puts parent_recording_id in service_args; Transition does not, so the
    # private reader is the fallback. Upstream ask: a public parent_recording_id.
    def parent_recording_id_for(service)
      service.send(:service_args)[:parent_recording_id] || service.send(:parent_recording)&.id
    end

    def sent?(parent_recording_id)
      return false if parent_recording_id.blank?

      recordable_id = RecordingStudio::Recording.where(
        id: parent_recording_id, recordable_type: Broadcast.name
      ).pick(:recordable_id)
      return false if recordable_id.nil?

      Broadcast.where(id: recordable_id).pick(:sent_at).present?
    end

    def failure
      RecordingStudio::Services::BaseService::Result.new(success: false, error: MESSAGE, errors: [MESSAGE])
    end
  end
end
