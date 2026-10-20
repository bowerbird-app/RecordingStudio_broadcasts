# frozen_string_literal: true

module RecordingStudioBroadcasts
  # A sent broadcast stays published, but nobody may edit that Publishable record
  # except Broadcasts itself. Publishable's Update and Transition both run through
  # around_service. Transition#perform calls Update.call, which starts its own
  # around_service, so a direct field edit and a nested transition write are the
  # same check. Refusing Transition before yielding means that nested Update never
  # starts. BaseService#failure is private, so the hook builds the public Result.
  #
  # v0.9.2 Transition does not define service_args (the base method returns {}).
  # TransitionParent records the parent id so the lock can read service_args for both.
  module SentPublishableLock
    MESSAGE = "A sent broadcast cannot be changed."

    LOCKED_SERVICES = [
      RecordingStudioPublishable::Services::Publishables::Update,
      RecordingStudioPublishable::Services::Publishables::Transition
    ].freeze

    module TransitionParent
      def initialize(parent_recording:, **)
        @sent_lock_parent_recording_id = parent_recording&.id
        super
      end

      private

      def service_args
        super.merge(parent_recording_id: @sent_lock_parent_recording_id)
      end
    end

    module_function

    def install!
      transition = RecordingStudioPublishable::Services::Publishables::Transition
      transition.prepend(TransitionParent) unless transition.ancestors.include?(TransitionParent)

      RecordingStudioPublishable.configuration.hooks.around_service do |service, inner|
        RecordingStudioBroadcasts::SentPublishableLock.refusal_for(service) || inner.call
      end
    end

    def refusal_for(service)
      return unless LOCKED_SERVICES.include?(service.class)

      parent_recording_id = service.send(:service_args)[:parent_recording_id]
      return if PublishableWrite.own_publishable_write?(parent_recording_id)
      return unless sent?(parent_recording_id)

      failure
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
