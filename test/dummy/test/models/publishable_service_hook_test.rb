# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class PublishableServiceHookTest < ActiveSupport::TestCase
  class OtherService < RecordingStudio::Services::BaseService
    def perform
      success("ran")
    end
  end

  setup do
    reset_tables!
    @admin = create_user("admin@admin.com")
    grant_sender!(@admin)
    Current.actor = @admin
    @message = RecordingStudioBroadcasts::SentPublishableLock::MESSAGE
    @raise_on_error = RecordingStudio.configuration.hooks.raise_on_error
    reset_service_hooks!
  end

  teardown do
    RecordingStudio.configuration.hooks.raise_on_error = @raise_on_error
    reset_service_hooks!
    reset_tables!
  end

  test "update and transition on a sent broadcast return the lock failure" do
    sent = sent_broadcast
    refute RecordingStudio.configuration.hooks.raise_on_error

    update = update_social(sent, "Changed in Publishable")
    transition = RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: sent, actor: @admin, transition: "unpublish"
    )

    assert_failure update
    assert_failure transition
    assert_equal "Already sent card", sent.reload.current_publishable.social_title
    assert_equal "published", sent.current_publishable.status
    assert_equal "sending", broadcast_status(sent)
  end

  test "a service outside publishable passes through and after_service ignores it" do
    scheduled = create_broadcast(actor: @admin)
    at = 2.days.from_now.change(usec: 0)
    RecordingStudioBroadcasts.schedule(scheduled, at:, actor: @admin)
    publish_at = scheduled.reload.current_publishable.publish_at

    RecordingStudio.configuration.hooks.raise_on_error = true
    result = OtherService.call

    assert_predicate result, :success?
    assert_equal "ran", result.value
    assert_equal "scheduled", broadcast_status(scheduled)
    assert_equal publish_at.to_i, scheduled.reload.current_publishable.publish_at.to_i
  end

  test "the lock is outermost around a default priority hook" do
    sent = sent_broadcast
    sentinel = Object.new
    RecordingStudio.configuration.hooks.around_service { |_service, _inner| sentinel }

    result = update_social(sent, "Changed from the inner hook")

    assert_failure result
    refute_same sentinel, result
    assert_equal "Already sent card", sent.reload.current_publishable.social_title
  end

  test "reinstall after a hook reset restores the lock and listeners once" do
    sent = sent_broadcast
    event_name = RecordingStudioPublishable::LifecycleNotifications.event_name_for(:published)
    assert_equal 1, published_deliveries(event_name)

    RecordingStudio.configuration.hooks.clear!
    opened = update_social(sent, "Edited while the lock was gone")

    assert_predicate opened, :success?
    assert_equal "Edited while the lock was gone", sent.reload.current_publishable.social_title

    RecordingStudioBroadcasts.install_publish_delivery!
    RecordingStudioBroadcasts.install_publish_delivery!
    blocked = update_social(sent, "Edited after the lock returned")

    assert_failure blocked
    assert_equal "Edited while the lock was gone", sent.reload.current_publishable.social_title
    assert_equal 1, published_deliveries(event_name)
  end

  private

  def sent_broadcast
    recording = create_broadcast(actor: @admin)
    RecordingStudioBroadcasts.publish_now(recording, actor: @admin)
    assert_predicate recording.reload.recordable.sent_at, :present?
    RecordingStudioBroadcasts::PublishableWrite.own_write(recording) do
      update_social(recording, "Already sent card")
    end
    recording
  end

  def update_social(recording, title)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording, actor: @admin, attributes: { social_title: title }
    )
  end

  def assert_failure(result)
    assert_kind_of RecordingStudio::Services::BaseService::Result, result
    assert_predicate result, :failure?
    assert_equal @message, result.error
    assert_equal [@message], result.errors
  end

  def published_deliveries(event_name)
    calls = 0
    RecordingStudioBroadcasts::Campaign.stub(:deliver_published, ->(_payload) { calls += 1 }) do
      ActiveSupport::Notifications.instrument(event_name, { source: "test" })
    end
    calls
  end

  def reset_service_hooks!
    RecordingStudio.configuration.hooks.clear!
    RecordingStudioBroadcasts.install_publish_delivery!
  end
end
