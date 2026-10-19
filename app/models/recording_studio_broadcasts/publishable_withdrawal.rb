# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Publishable's own edit of a live record, and the send-time access check.
  module PublishableWithdrawal
    # A scheduled broadcast goes back to draft so that clock cannot send.
    def withdraw_after_publishable_change(payload)
      return unless payload[:recordable_type] == Broadcast.name

      recording = RecordingStudio::Recording.find_by(id: payload[:recording_id])
      return if recording.nil? || recording.recordable.status != "scheduled"
      # Scheduling a live publishable writes a future publish_at. That leaves
      # the live window and emits unpublished. It is this broadcast's own clock.
      return if keeping_schedule?(recording, payload)

      revise!(recording, actor: actor_from(payload), status: "draft", scheduled_at: nil)
    end

    # Publishable's after_service hook runs in-process on every Update, including
    # a future publish_at edit that never becomes a lifecycle event.
    def note_external_publishable_write(service_class, result)
      return unless external_publishable_update?(service_class, result)

      child = result.value
      recording = broadcast_recording_for(child)
      return if recording.nil?
      return unless send_clock_left?(recording, child.recordable)

      return_to_draft!(recording, editor_for(child))
    end

    # The window job's clock no longer matches. The broadcast cannot send, so it goes back to draft.
    def release_mismatched_schedule!(recording, payload)
      revise!(recording, actor: actor_from(payload), status: "draft", scheduled_at: nil)
    end

    def external_publishable_update?(service_class, result)
      service_class == RecordingStudioPublishable::Services::Publishables::Update &&
        result.respond_to?(:success?) && result.success? &&
        !PublishableWrite.own_publishable_write?
    end

    def broadcast_recording_for(child)
      recording = child.respond_to?(:parent_recording) ? child.parent_recording : nil
      recording if recording&.recordable_type == Broadcast.name
    end

    def send_clock_left?(recording, publishable)
      broadcast = recording.recordable
      return false unless broadcast.status == "scheduled"

      drafted?(publishable) || publishable.currently_published? ||
        !same_clock?(publishable.publish_at, broadcast.scheduled_at)
    end

    def drafted?(publishable)
      publishable.status == "draft"
    end

    def editor_for(child)
      child.events(actions: "updated", limit: 1).find { |event| publishable_update?(event) }&.actor
    end

    def publishable_update?(event)
      event.metadata.to_h.stringify_keys["source"] == "recording_studio_publishable.update"
    end

    def return_to_draft!(recording, editor)
      revise!(
        recording,
        actor: editor,
        status: "draft",
        scheduled_at: nil,
        metadata: { source: "publishable_change" }
      )
    end

    def keeping_schedule?(recording, payload)
      state = payload.fetch(:current_state, {})
      return false unless state[:scheduled]

      same_clock?(state[:publish_at], recording.recordable.scheduled_at)
    end

    def same_clock?(publish_at, scheduled_at)
      return false if publish_at.blank? || scheduled_at.blank?

      publish_at.utc.iso8601 == scheduled_at.utc.iso8601
    end

    def sender_allowed?(recording, actor)
      return false if actor.nil?

      context = RecordingStudioAdmin::Context.new(current_actor: actor)
      RecordingStudioAdmin.authorize_resource!(
        key: "broadcasts", action: :send, context: context, record: recording
      )
      true
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      false
    end
  end
end
