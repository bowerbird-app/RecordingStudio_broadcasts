# frozen_string_literal: true

require "test_helper"

class BroadcastDeliveryTest < ActiveSupport::TestCase
  # WindowTransitionJob emits after the surrounding transaction commits.
  # The fixture transaction would swallow that, so these tests commit.
  self.use_transactional_tests = false

  include ActiveSupport::Testing::TimeHelpers

  Campaign = RecordingStudioBroadcasts::Campaign
  Delivery = RecordingStudioBroadcasts::Delivery
  Recipient = RecordingStudioBroadcasts::Recipient

  setup do
    reset_tables!
    ActionMailer::Base.deliveries.clear
    @ann = create_user("ann@example.com")
    @bob = create_user("bob@example.com")
    grant_sender!(@ann)
    Current.actor = @ann
    @recording = create_broadcast
  end

  teardown { reset_tables! }

  test "launch emails each ready person once and completes" do
    assert_emails 2 do
      perform_enqueued_jobs { RecordingStudioBroadcasts.launch(@recording, actor: @ann) }
    end

    mail = ActionMailer::Base.deliveries.find { |message| message.to == [ "bob@example.com" ] }
    text = mail.text_part.decoded
    assert_equal "What's new in October", mail.subject
    assert_includes text, "We shipped broadcasts."
    assert_equal 1, text.scan("Unsubscribe:").size
    assert_match %r{\A<http://example.com/notifications/unsubscribe/product_update/email\?token=.+>\z},
                 mail["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", mail["List-Unsubscribe-Post"].value
    assert_equal %w[sent sent], Recipient.where(recording_id: @recording.id).pluck(:status)
    assert_equal "completed", broadcast_status(@recording)
    assert_raises(ArgumentError) { RecordingStudioBroadcasts.launch(@recording, actor: nil) }
  end

  test "a retry after the snapshot rows were not recorded sends nothing more" do
    start_sending!
    key = Delivery.idempotency_key(@recording)

    Delivery.stub(:finish, nil) do
      assert_emails(2) { deliver! }
      assert_equal 2, notifications_for(key).count

      Recipient.where(recording_id: @recording.id).update_all(
        status: "pending", skip_reason: nil, notification_id: nil, claimed_at: nil, updated_at: Time.current
      )

      assert_no_emails { deliver! }
    end

    assert_equal %w[sent sent], Recipient.where(recording_id: @recording.id).pluck(:status)
    assert_equal 2, notifications_for(key).count
    Delivery.finish(@recording, @ann)
    assert_equal "completed", broadcast_status(@recording)
  end

  test "cancel skips the people not yet sent to and sends nothing more" do
    RecordingStudioBroadcasts.launch(@recording, actor: @ann)
    RecordingStudioBroadcasts.cancel(@recording, actor: @ann)

    assert_no_emails { 4.times { perform_enqueued_jobs } }
    assert_equal [ %w[skipped cancelled] ] * 2, Recipient.where(recording_id: @recording.id).pluck(:status, :skip_reason)
    assert_equal "cancelled", broadcast_status(@recording)
    assert_no_enqueued_jobs
  end

  test "cancel during fan-out stops the chunks that have not been loaded" do
    start_sending!
    chunks = 0
    record_chunk = Delivery.method(:record_chunk)

    Delivery.stub(:record_chunk, lambda { |recording, people|
      record_chunk.call(recording, people)
      chunks += 1
      RecordingStudioBroadcasts.cancel(@recording, actor: @ann) if chunks == 1
    }) do
      RecordingStudioNotifications::Services::FanOut.stub(:chunk_size, 1) do
        assert_emails(1) { deliver! }
      end
    end

    counts = Recipient.where(recording_id: @recording.id).group(:status, :skip_reason).count
    assert_equal 1, counts[["sent", nil]]
    assert_equal 1, counts[["skipped", "cancelled"]]
    assert_equal "cancelled", broadcast_status(@recording)
  end

  test "an email adapter delivery error marks that person failed and still sends the others" do
    start_sending!
    adapter = RecordingStudioNotifications.channels.fetch(:email)
    original = adapter.method(:deliver)

    adapter.stub(:deliver, failure_for(@bob, original)) do
      assert_emails(1) { deliver! }
    end

    bob = Recipient.find_by!(recording_id: @recording.id, recipient_id: @bob.id)
    ann = Recipient.find_by!(recording_id: @recording.id, recipient_id: @ann.id)
    assert_equal "failed", bob.status
    assert_equal "sent", ann.status
    delivery = RecordingStudioNotifications::Notification.find(bob.notification_id).deliveries.find_by!(channel: "email")
    refute_predicate delivery, :delivered?
    assert_match(/from/i, delivery.error_message)
    assert_equal "completed", broadcast_status(@recording)
  end

  test "someone who turns product updates off after launch is skipped without a notification" do
    start_sending!
    RecordingStudioNotifications::Preference.set!(
      recipient: @bob, notification_type: :product_update, channel: :email, enabled: false
    )

    assert_no_difference -> { RecordingStudioNotifications::Notification.where(recipient_id: @bob.id).count } do
      assert_emails(1) { deliver! }
    end

    row = Recipient.find_by!(recording_id: @recording.id, recipient_id: @bob.id)
    assert_equal [ "skipped", "preference" ], [ row.status, row.skip_reason ]
    assert_equal "sent", Recipient.find_by!(recording_id: @recording.id, recipient_id: @ann.id).status
    assert_equal "completed", broadcast_status(@recording)
  end

  test "a suppressed address is skipped with reason suppressed" do
    start_sending!
    RecordingStudioNotificationsEmail::Suppression.suppress!(
      address: "bob@example.com", reason: "complaint", provider: "test"
    )

    assert_emails(1) { deliver! }

    row = Recipient.find_by!(recording_id: @recording.id, recipient_id: @bob.id)
    assert_equal [ "skipped", "suppressed" ], [ row.status, row.skip_reason ]
    assert_equal [ "ann@example.com" ], ActionMailer::Base.deliveries.flat_map(&:to)
    assert_equal "completed", broadcast_status(@recording)
  end

  test "a test send emails only the person asking and leaves the draft alone" do
    assert_emails(1) { RecordingStudioBroadcasts.test_send(@recording, actor: @ann) }

    assert_equal [ "ann@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "draft", broadcast_status(@recording)
    assert_equal 0, Recipient.where(recording_id: @recording.id).count
  end

  test "a test send with a missing from does not raise" do
    notification = RecordingStudioNotificationsEmail.configuration.stub(:from, nil) do
      RecordingStudioBroadcasts.test_send(@recording, actor: @ann)
    end

    assert_predicate notification, :persisted?
    assert_equal "draft", broadcast_status(@recording)
    delivery = notification.deliveries.find_by!(channel: "email")
    refute_predicate delivery, :delivered?
  end

  test "the scheduled job launches at the latest schedule and the superseded job does nothing" do
    first = 1.hour.from_now.change(usec: 0)
    latest = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at: first, actor: @ann)
    RecordingStudioBroadcasts.schedule(@recording, at: latest, actor: @ann)

    travel_to(first + 1.minute) do
      perform_enqueued_jobs(only: RecordingStudioPublishable::WindowTransitionJob, at: Time.current)
      assert_equal "scheduled", broadcast_status(@recording)
      assert_no_enqueued_jobs(only: RecordingStudioBroadcasts::DeliverBroadcastJob)
    end

    travel_to(latest + 1.minute) do
      perform_enqueued_jobs(only: RecordingStudioPublishable::WindowTransitionJob, at: Time.current)
      assert_equal "sending", broadcast_status(@recording)
    end
    assert_enqueued_with(job: RecordingStudioBroadcasts::DeliverBroadcastJob, args: [ @recording, @ann ])
  end

  private

  def start_sending!
    RecordingStudioBroadcasts::Audience.snapshot!(@recording)
    Campaign.revise!(@recording, actor: @ann, status: "sending")
  end

  def deliver!
    perform_enqueued_jobs { RecordingStudioBroadcasts::DeliverBroadcastJob.perform_now(@recording, @ann) }
  end

  def notifications_for(key)
    RecordingStudioNotifications::Notification.where(idempotency_key: key)
  end

  def failure_for(person, original)
    lambda do |notification:, delivery:|
      raise RecordingStudioNotificationsEmail::DeliveryError, "from is missing" if notification.recipient_id == person.id

      original.call(notification:, delivery:)
    end
  end
end
