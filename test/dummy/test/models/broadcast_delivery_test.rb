# frozen_string_literal: true

require "test_helper"

class BroadcastDeliveryTest < ActiveSupport::TestCase
  Campaign = RecordingStudioBroadcasts::Campaign
  Delivery = RecordingStudioBroadcasts::Delivery
  Recipient = RecordingStudioBroadcasts::Recipient

  setup do
    @ann = create_user("ann@example.com")
    @bob = create_user("bob@example.com")
    @recording = create_broadcast
  end

  test "launch emails each ready person once with an unsubscribe line and completes" do
    assert_emails 2 do
      perform_enqueued_jobs { RecordingStudioBroadcasts.launch(@recording, actor: @ann) }
    end

    mail = ActionMailer::Base.deliveries.find { |message| message.to == [ "bob@example.com" ] }
    assert_equal "What's new in October", mail.subject
    assert_includes mail.text_part.decoded, "We shipped broadcasts."
    assert_match %r{Unsubscribe: http://example.com/notifications/unsubscribe/product_update/email\?token=}, mail.text_part.decoded
    assert_equal %w[sent sent], Recipient.where(recording_id: @recording.id).pluck(:status)
    assert_equal "completed", broadcast_status(@recording)
  end

  test "a retry after a crash finds the existing notification and sends nothing more" do
    RecordingStudioBroadcasts::Audience.snapshot!(@recording)
    Campaign.revise!(@recording, actor: nil, status: "sending")
    row = Recipient.find_by!(recording_id: @recording.id, recipient_id: @ann.id)
    assert_emails(1) { Delivery.deliver_one(row) }
    row.update_columns(status: "sending", notification_id: nil, claimed_at: 20.minutes.ago)

    assert_emails 1 do
      perform_enqueued_jobs { RecordingStudioBroadcasts::DeliverBroadcastJob.perform_now(@recording) }
    end

    assert_equal "sent", row.reload.status
    assert_predicate row.notification_id, :present?
    assert_equal "completed", broadcast_status(@recording)
    assert_no_emails { perform_enqueued_jobs { RecordingStudioBroadcasts.launch(@recording, actor: nil) } }
  end

  test "cancel skips the people not yet sent to and sends nothing more" do
    RecordingStudioBroadcasts.launch(@recording, actor: nil)
    RecordingStudioBroadcasts.cancel(@recording, actor: nil)

    assert_no_emails { perform_enqueued_jobs }
    assert_equal [ %w[skipped cancelled] ] * 2, Recipient.where(recording_id: @recording.id).pluck(:status, :skip_reason)
    assert_equal "cancelled", broadcast_status(@recording)
    assert_no_enqueued_jobs
  end

  test "someone who turns product updates off after launch is skipped without a notification" do
    RecordingStudioBroadcasts::Audience.snapshot!(@recording)
    Campaign.revise!(@recording, actor: nil, status: "sending")
    RecordingStudioNotifications::Preference.set!(
      recipient: @bob, notification_type: :product_update, channel: :email, enabled: false
    )
    row = Recipient.find_by!(recording_id: @recording.id, recipient_id: @bob.id)

    assert_no_difference -> { RecordingStudioNotifications::Notification.count } do
      assert_no_emails { Delivery.deliver_one(row) }
    end
    assert_equal [ "skipped", "preference" ], [ row.reload.status, row.skip_reason ]
  end

  test "a suppressed address is skipped with reason suppressed" do
    RecordingStudioBroadcasts::Audience.snapshot!(@recording)
    Campaign.revise!(@recording, actor: nil, status: "sending")
    RecordingStudioNotificationsEmail::Suppression.suppress!(address: "bob@example.com", reason: "complaint", provider: "test")
    row = Recipient.find_by!(recording_id: @recording.id, recipient_id: @bob.id)

    assert_no_emails { Delivery.deliver_one(row) }
    assert_equal [ "skipped", "suppressed" ], [ row.reload.status, row.skip_reason ]
  end

  test "a test send emails only the person asking and leaves the draft alone" do
    assert_emails(1) { RecordingStudioBroadcasts.test_send(@recording, actor: @ann) }

    assert_equal [ "ann@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "draft", broadcast_status(@recording)
    assert_equal 0, Recipient.where(recording_id: @recording.id).count
  end

  test "the scheduled job launches at the latest schedule and the superseded job does nothing" do
    first = 1.hour.from_now
    latest = 2.hours.from_now
    RecordingStudioBroadcasts.schedule(@recording, at: first, actor: @ann)
    RecordingStudioBroadcasts.schedule(@recording, at: latest, actor: @ann)

    perform_enqueued_jobs(only: RecordingStudioBroadcasts::ScheduledBroadcastJob, at: first + 1.minute)
    assert_equal "scheduled", broadcast_status(@recording)
    assert_no_enqueued_jobs(only: RecordingStudioBroadcasts::DeliverBroadcastJob)

    perform_enqueued_jobs(only: RecordingStudioBroadcasts::ScheduledBroadcastJob, at: latest + 1.minute)
    assert_equal "sending", broadcast_status(@recording)
    assert_enqueued_with(job: RecordingStudioBroadcasts::DeliverBroadcastJob, args: [ @recording, @ann ])
  end
end
