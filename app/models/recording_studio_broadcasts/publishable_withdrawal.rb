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

    # The window job's clock no longer matches. The broadcast cannot send, so it goes back to draft.
    def release_mismatched_schedule!(recording, payload)
      revise!(recording, actor: actor_from(payload), status: "draft", scheduled_at: nil)
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
