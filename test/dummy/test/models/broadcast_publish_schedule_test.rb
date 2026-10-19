# frozen_string_literal: true

require "test_helper"

class BroadcastPublishScheduleTest < ActiveSupport::TestCase
  # WindowTransitionJob emits after the surrounding transaction commits.
  # The fixture transaction would swallow that, so these tests commit.
  self.use_transactional_tests = false

  include ActiveSupport::Testing::TimeHelpers

  setup do
    reset_tables!
    ActionMailer::Base.deliveries.clear
    @ann = create_user("ann@example.com")
    @bob = create_user("bob@example.com")
    @recording = create_broadcast
  end

  teardown { reset_tables! }

  test "scheduling stores publishable's publish time and waits for that job" do
    at = Time.zone.parse("2026-10-24 15:00")

    assert_enqueued_with(job: RecordingStudioPublishable::WindowTransitionJob) do
      RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    end

    publishable = @recording.reload.current_publishable
    assert_equal "scheduled", broadcast_status(@recording)
    assert_equal at, publishable.publish_at
    assert_nil @recording.recordable.sent_at
    assert_equal 0, RecordingStudioBroadcasts::Recipient.where(recording_id: @recording.id).count
  end

  test "publishing with no future time sends immediately" do
    assert_emails 2 do
      perform_enqueued_jobs { RecordingStudioBroadcasts.publish_now(@recording, actor: @ann) }
    end

    broadcast = @recording.reload.recordable
    assert_equal "completed", broadcast.status
    assert_predicate broadcast.sent_at, :present?
    assert_predicate @recording.current_publishable.publish_at, :present?
    assert_operator @recording.current_publishable.publish_at, :<=, Time.current
  end

  test "travel_to the publish time sends once" do
    at = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)

    travel_to(at - 1.minute) do
      assert_no_emails { perform_enqueued_jobs(at: Time.current) }
      assert_equal "scheduled", broadcast_status(@recording)
    end

    travel_to(at + 1.second) do
      assert_emails 2 do
        drain_due_jobs
      end
    end

    assert_equal "completed", broadcast_status(@recording)
    assert_predicate @recording.reload.recordable.sent_at, :present?
  end

  test "rescheduling sends at the new time and the earlier job does nothing" do
    first = 1.hour.from_now.change(usec: 0)
    latest = 3.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at: first, actor: @ann)
    RecordingStudioBroadcasts.schedule(@recording, at: latest, actor: @ann)

    travel_to(first + 1.minute) do
      assert_no_emails { perform_enqueued_jobs(at: Time.current) }
      assert_equal "scheduled", broadcast_status(@recording)
      assert_nil @recording.reload.recordable.sent_at
    end

    travel_to(latest + 1.second) do
      assert_emails 2 do
        drain_due_jobs
      end
    end

    assert_equal "completed", broadcast_status(@recording)
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "unpublishing before the publish time sends nothing" do
    at = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    RecordingStudioBroadcasts.unpublish(@recording, actor: @ann)

    assert_equal "draft", broadcast_status(@recording)
    assert_nil @recording.reload.recordable.scheduled_at
    refute @recording.current_publishable.scheduled_for_future?

    travel_to(at + 1.minute) do
      assert_no_emails { perform_enqueued_jobs(at: Time.current) }
    end

    assert_nil @recording.reload.recordable.sent_at
    assert_equal 0, RecordingStudioBroadcasts::Recipient.where(recording_id: @recording.id).count
  end

  test "a second publish after the send does not send again" do
    at = 1.hour.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)

    travel_to(at + 1.second) do
      assert_emails 2 do
        drain_due_jobs
      end

      assert_no_emails do
        RecordingStudioBroadcasts.launch(@recording, actor: @ann)
        assert_raises(RecordingStudioBroadcasts::InvalidTransition) do
          RecordingStudioBroadcasts.publish_now(@recording, actor: @ann)
        end
      end
    end

    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal "completed", broadcast_status(@recording)
  end

  test "a non-UTC zone keeps a DST overlap instant" do
    zone = ActiveSupport::TimeZone["America/New_York"]
    at = zone.local(2026, 11, 1, 1, 30, 0)

    Time.use_zone(zone) do
      RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    end

    assert_equal at.to_i, @recording.reload.current_publishable.publish_at.to_i
    assert_equal "scheduled", broadcast_status(@recording)
  end

  test "publishing a draft through Publishable does not send" do
    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: @recording, transition: "publish", actor: @ann
    )

    assert_no_enqueued_jobs(only: RecordingStudioBroadcasts::DeliverBroadcastJob)
    assert_no_emails { perform_enqueued_jobs }
    assert_nil @recording.reload.recordable.sent_at
    assert_equal "draft", broadcast_status(@recording)
  end

  test "a failure while revising the broadcast rolls the schedule back" do
    at = 2.hours.from_now.change(usec: 0)
    campaign = RecordingStudioBroadcasts::Campaign
    campaign.singleton_class.alias_method(:revise_before_failure_test!, :revise!)
    campaign.define_singleton_method(:revise!) { |*, **| raise ActiveRecord::RecordNotSaved, "stopped" }

    assert_no_enqueued_jobs only: RecordingStudioPublishable::WindowTransitionJob do
      assert_raises(ActiveRecord::RecordNotSaved) do
        RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
      end
    end

    assert_equal "draft", broadcast_status(@recording)
    assert_nil @recording.reload.current_publishable
  ensure
    campaign.singleton_class.alias_method(:revise!, :revise_before_failure_test!)
  end

  test "publish now enqueues delivery once" do
    assert_enqueued_jobs 1, only: RecordingStudioBroadcasts::DeliverBroadcastJob do
      RecordingStudio::Recording.transaction do
        RecordingStudioBroadcasts.publish_now(@recording, actor: @ann)
      end
    end
  end

  test "cancel then the window job sends nothing and the publishable is not published" do
    at = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    RecordingStudioBroadcasts.cancel(@recording, actor: @ann)

    assert_equal "cancelled", broadcast_status(@recording)
    assert_equal "draft", @recording.reload.current_publishable.status

    travel_to(at + 1.minute) do
      assert_no_emails { drain_due_jobs }
    end

    assert_nil @recording.reload.recordable.sent_at
    assert_equal 0, RecordingStudioBroadcasts::Recipient.where(recording_id: @recording.id).count
  end

  private

  # The window job enqueues delivery when it runs, so one flush is not enough.
  def drain_due_jobs
    4.times { perform_enqueued_jobs(at: Time.current) }
  end
end
