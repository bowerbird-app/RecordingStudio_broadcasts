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
    grant_sender!(@ann)
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

    assert_raises(ActiveRecord::RecordNotSaved) do
      RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    end

    assert_equal "draft", broadcast_status(@recording)
    assert_nil @recording.reload.current_publishable
    assert_no_emails { perform_enqueued_jobs }
  ensure
    campaign.singleton_class.alias_method(:revise!, :revise_before_failure_test!)
  end

  test "moving publish_at earlier in Publishable returns the broadcast to draft" do
    later = 3.hours.from_now.change(usec: 0)
    sooner = 1.hour.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at: later, actor: @ann)

    edit_publishable!(status: "scheduled", publish_at: sooner.utc.iso8601)

    assert_returned_to_draft_by!(editor)
    travel_to(sooner + 1.second) { assert_no_emails { drain_due_jobs } }
    travel_to(later + 1.second) { assert_no_emails { drain_due_jobs } }
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "moving publish_at later in Publishable returns the broadcast to draft" do
    sooner = 1.hour.from_now.change(usec: 0)
    later = 4.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at: sooner, actor: @ann)

    edit_publishable!(status: "scheduled", publish_at: later.utc.iso8601)

    assert_returned_to_draft_by!(editor)
    travel_to(sooner + 1.second) { assert_no_emails { drain_due_jobs } }
    travel_to(later + 1.second) { assert_no_emails { drain_due_jobs } }
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "publishing now through Publishable returns the scheduled broadcast to draft" do
    at = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)

    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: @recording, transition: "publish", actor: editor
    )

    assert_returned_to_draft_by!(editor)
    assert_no_enqueued_jobs(only: RecordingStudioBroadcasts::DeliverBroadcastJob)
    travel_to(at + 1.second) { assert_no_emails { drain_due_jobs } }
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "unpublishing or drafting through Publishable before it is live returns the broadcast to draft" do
    %w[unpublish draft].each do |transition|
      recording = create_broadcast
      at = 2.hours.from_now.change(usec: 0)
      RecordingStudioBroadcasts.schedule(recording, at:, actor: @ann)

      RecordingStudioPublishable::Services::Publishables::Transition.call(
        parent_recording: recording, transition:, actor: editor
      )

      assert_equal "draft", broadcast_status(recording)
      assert_nil recording.reload.recordable.scheduled_at
      assert_equal editor, publishable_change_event(recording).actor
      travel_to(at + 1.second) { assert_no_emails { drain_due_jobs } }
    end

    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "an own publishable write does not return the scheduled broadcast to draft" do
    at = 2.hours.from_now.change(usec: 0)
    later = 4.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)

    RecordingStudioBroadcasts::PublishableWrite.own_write do
      edit_publishable!(status: "scheduled", publish_at: later.utc.iso8601)
    end

    assert_equal "scheduled", broadcast_status(@recording)
    assert_equal at, @recording.reload.recordable.scheduled_at
    assert_nil publishable_change_event(@recording)
  end

  test "a failed return to draft is logged and retried in a later transaction" do
    at = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    campaign = RecordingStudioBroadcasts::Campaign
    campaign.singleton_class.alias_method(:return_to_draft_before_failure!, :return_to_draft!)
    campaign.define_singleton_method(:return_to_draft!) { |*, **| raise ActiveRecord::RecordNotSaved, "stopped" }
    log = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)

    assert_enqueued_with(job: RecordingStudioBroadcasts::ReconcilePublishableChangeJob) do
      edit_publishable!(status: "scheduled", publish_at: 4.hours.from_now.utc.iso8601)
    end

    assert_equal "scheduled", broadcast_status(@recording)
    assert_includes log.string, "could not return recording #{@recording.id} to draft"
  ensure
    campaign.singleton_class.alias_method(:return_to_draft!, :return_to_draft_before_failure!)
    Rails.logger = previous_logger if previous_logger
    perform_enqueued_jobs
    assert_equal "draft", broadcast_status(@recording)
    assert_equal "Returned to draft: send time changed in Publishable by the system",
                 RecordingStudioBroadcasts::BroadcastsHelper.publishable_return_notice(@recording)
  end

  test "unpublishing a live publishable returns the scheduled broadcast to draft" do
    at = 1.hour.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    make_publishable_live!

    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: @recording, transition: "unpublish", actor: editor
    )

    assert_returned_to_draft_by!(editor)
  end

  test "revising a live publishable returns the scheduled broadcast to draft" do
    at = 1.hour.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    make_publishable_live!

    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @recording,
      actor: editor,
      attributes: { social_title: "Edited in Publishable" }
    )

    assert_returned_to_draft_by!(editor)
  end

  test "scheduling a live publishable stays scheduled and sends at that time" do
    RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: @recording, transition: "publish", actor: @ann
    )
    assert @recording.reload.current_publishable.currently_published?

    at = 2.hours.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)

    assert_equal "scheduled", broadcast_status(@recording)
    assert_equal at, @recording.reload.recordable.scheduled_at

    travel_to(at + 1.second) do
      assert_emails 2 do
        drain_due_jobs
      end
    end

    assert_equal "completed", broadcast_status(@recording)
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "duplicate window job sends once" do
    at = 2.hours.from_now.change(usec: 0)

    assert_enqueued_jobs 2, only: RecordingStudioPublishable::WindowTransitionJob do
      RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
      RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    end

    travel_to(at + 1.second) do
      assert_emails 2 do
        drain_due_jobs
      end
    end

    assert_equal "completed", broadcast_status(@recording)
    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal 2, RecordingStudioBroadcasts::Recipient.where(recording_id: @recording.id).count
  end

  test "a scheduler who lost send access does not launch" do
    at = 1.hour.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(@recording, at:, actor: @ann)
    access = RecordingStudio::Access.find_by!(actor: @ann)
    RecordingStudio::Access.where(id: access.id).update_all(role: "view")

    log = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    travel_to(at + 1.minute) do
      assert_no_emails { drain_due_jobs }
    end

    assert_equal "scheduled", broadcast_status(@recording)
    assert_nil @recording.reload.recordable.sent_at
    assert_includes log.string, @recording.id
  ensure
    Rails.logger = previous_logger if previous_logger
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

  def editor
    @cara ||= create_user("cara@example.com")
  end

  def make_publishable_live!
    RecordingStudioBroadcasts::PublishableWrite.own_write do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: @recording,
        actor: @ann,
        attributes: {
          status: "published",
          publish_at: 1.minute.ago.utc.iso8601,
          time_zone: Time.zone.tzinfo.name
        }
      )
    end
    assert_predicate @recording.reload.current_publishable, :currently_published?
    assert_equal "scheduled", broadcast_status(@recording)
  end

  def edit_publishable!(attributes)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @recording,
      actor: editor,
      attributes: attributes.merge(time_zone: Time.zone.tzinfo.name)
    )
  end

  def assert_returned_to_draft_by!(actor)
    assert_equal "draft", broadcast_status(@recording)
    assert_nil @recording.reload.recordable.scheduled_at
    assert_nil @recording.recordable.sent_at
    assert_equal actor, publishable_change_event(@recording).actor
    assert_equal "Returned to draft: send time changed in Publishable by #{actor.email}",
                 RecordingStudioBroadcasts::BroadcastsHelper.publishable_return_notice(@recording)
  end

  def publishable_change_event(recording)
    recording.events(actions: "updated").find do |event|
      event.metadata.to_h.stringify_keys["source"] == "publishable_change"
    end
  end
end
