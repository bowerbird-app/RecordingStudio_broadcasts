# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Edit is an admin action, but the resource hides Update once sent_at is set.
  # That check would refuse the request before this redirect, so admin access is
  # checked on its own and the admin is sent back to the broadcasts list.
  module SentBroadcastEdit
    extend ActiveSupport::Concern

    private

    def sent_broadcast?
      @recording.recordable.sent_at.present?
    end

    def redirect_sent_broadcast
      RecordingStudioAdmin::Authorization.authorize!(
        recording_studio_admin_context,
        role: BroadcastsResource.action_for(:update).required_access_role
      )
      redirect_to recording_studio_admin_context.admin_screen_path("broadcasts"), alert: SentPublishableLock::MESSAGE
    end
  end
end
