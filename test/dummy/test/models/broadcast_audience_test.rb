# frozen_string_literal: true

require "test_helper"

class BroadcastAudienceTest < ActiveSupport::TestCase
  setup do
    create_user("old@example.com", created_at: Time.zone.parse("2000-01-01"))
    @ready = create_user("ready@example.com", created_at: Time.zone.parse("2100-01-01"))
    create_user("bounced@example.com", created_at: Time.zone.parse("2100-01-02"))
    @opted_out = create_user("optout@example.com", created_at: Time.zone.parse("2100-01-03"))

    RecordingStudioNotificationsEmail::Suppression.suppress!(address: "bounced@example.com", reason: "bounce", provider: "test")
    RecordingStudioNotifications::Preference.set!(
      recipient: @opted_out, notification_type: :product_update, channel: :email, enabled: false
    )
    @recording = create_broadcast(filter_params: { "registered_after" => "2099-12-31" })
  end

  test "preview counts matching, ready, and left out people without sending or saving anything" do
    counts = nil

    assert_no_difference -> { RecordingStudioNotifications::Notification.count } do
      assert_no_difference -> { RecordingStudioBroadcasts::Recipient.count } do
        assert_no_emails { counts = RecordingStudioBroadcasts.preview(@recording) }
      end
    end

    assert_equal({ matching: 3, eligible: 1, excluded: 2 }, counts)
  end

  test "the registered filter narrows the host relation and blank values are ignored" do
    matching = RecordingStudioBroadcasts::Audience.matching_scope("registered_after" => "2099-12-31")
    everyone = RecordingStudioBroadcasts::Audience.matching_scope("registered_after" => "")

    assert_equal %w[bounced@example.com optout@example.com ready@example.com], matching.pluck(:email).sort
    assert_includes everyone.pluck(:email), "old@example.com"
  end

  test "snapshot inserts each ready person once" do
    2.times { RecordingStudioBroadcasts::Audience.snapshot!(@recording) }

    rows = RecordingStudioBroadcasts::Recipient.where(recording_id: @recording.id)
    assert_equal [ [ "User", @ready.id, "pending", admin_root_recording.id ] ],
                 rows.pluck(:recipient_type, :recipient_id, :status, :root_recording_id)
  end
end
