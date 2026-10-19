# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Publishable's own edit of a live record, and the send-time access check.
  module PublishableWithdrawal
    # A scheduled broadcast goes back to draft so that clock cannot send.
    def withdraw_after_publishable_change(payload)
      return unless payload[:recordable_type] == Broadcast.name

      recording = RecordingStudio::Recording.find_by(id: payload[:recording_id])
      return if recording.nil? || recording.recordable.status != "scheduled"

      revise!(recording, actor: actor_from(payload), status: "draft", scheduled_at: nil)
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
