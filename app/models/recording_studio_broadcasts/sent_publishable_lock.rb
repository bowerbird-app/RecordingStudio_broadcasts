# frozen_string_literal: true

module RecordingStudioBroadcasts
  # A sent broadcast stays published, but nobody may edit that Publishable record
  # except Broadcasts itself. Update and Transition both run through Core's
  # around_service. Transition#perform calls Update.call, which starts its own
  # around_service, so a direct field edit and a nested transition write are the
  # same check. Refusing Transition before yielding means that nested Update never
  # starts. BaseService#failure is private, so the hook builds the public Result.
  module SentPublishableLock
    MESSAGE = "A sent broadcast cannot be changed."
    # Lower than Hooks::DEFAULT_PRIORITY (100) so this refusal wraps other around hooks.
    PRIORITY = 0
    LATCH = :recording_studio_broadcasts_sent_publishable_lock

    LOCKED_SERVICES = [
      RecordingStudioPublishable::Services::Publishables::Update,
      RecordingStudioPublishable::Services::Publishables::Transition
    ].freeze

    module_function

    def install!
      hooks = RecordingStudio.configuration.hooks
      return if hooks.registered?(LATCH)

      hooks.around_service(priority: PRIORITY) { |service, inner| refusal_for(service) || inner.call }
      hooks.on(LATCH) { true }
    end

    def locked_service?(service)
      LOCKED_SERVICES.include?(service.is_a?(Class) ? service : service.class)
    end

    def refusal_for(service)
      return unless locked_service?(service)

      parent_recording_id = parent_recording_id_for(service)
      return if PublishableWrite.own_publishable_write?(parent_recording_id)
      return unless sent?(parent_recording_id)

      failure
    end

    # service_args and parent_recording are private. Update puts parent_recording_id
    # in service_args. Transition does not, so the private reader is the fallback.
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
