# frozen_string_literal: true

require "test_helper"

class BroadcastCampaignTest < ActiveSupport::TestCase
  Campaign = RecordingStudioBroadcasts::Campaign

  test "a new broadcast is a draft child of the admin root" do
    recording = create_broadcast

    assert_equal admin_root_recording, recording.parent_recording
    assert_equal "draft", recording.recordable.status
    assert_predicate recording.recordable.created_at, :present?
  end

  test "edits revise the same recording and keep earlier snapshots" do
    recording = create_broadcast

    revised = Campaign.update(recording, actor: nil, subject: "Fresh subject", status: "sending")

    assert_equal recording.id, revised.id
    assert_equal "Fresh subject", revised.recordable.subject
    assert_equal "draft", revised.recordable.status
    assert_equal [ "What's new in October", "Fresh subject" ], revised.recordables.map(&:subject)
  end

  test "status follows the transition table" do
    recording = create_broadcast

    assert_raises(ActiveRecord::RecordInvalid) { Campaign.revise!(recording, actor: nil, status: "scheduled") }
    Campaign.revise!(recording, actor: nil, status: "scheduled", scheduled_at: 1.hour.from_now)
    Campaign.revise!(recording, actor: nil, status: "draft")
    error = assert_raises(RecordingStudioBroadcasts::InvalidTransition) do
      Campaign.revise!(recording, actor: nil, status: "completed")
    end

    assert_equal "A draft broadcast cannot become completed", error.message
    assert_equal "draft", broadcast_status(recording)
  end

  test "content locks once sending starts and cancelled is final" do
    recording = create_broadcast
    Campaign.revise!(recording, actor: nil, status: "sending")

    assert_raises(RecordingStudioBroadcasts::InvalidTransition) { Campaign.update(recording, actor: nil, body: "Changed") }

    Campaign.revise!(recording, actor: nil, status: "cancelled")
    assert_raises(RecordingStudioBroadcasts::InvalidTransition) do
      Campaign.revise!(recording, actor: nil, status: "draft")
    end
    assert_equal "cancelled", broadcast_status(recording)
  end
end
