# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "minitest/mock"

class SentBroadcastLockTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    reset_tables!
    @admin = create_user("admin@admin.com")
    @viewer = create_user("viewer@example.com")
    grant_sender!(@admin)
    assert RecordingStudioAccessible.grant_access(
      recording: admin_root_recording, actor: @viewer, role: "view", manager_actor: @admin
    ).success?
    @message = RecordingStudioBroadcasts::SentPublishableLock::MESSAGE
  end

  test "publishable services routes json and api refuse a sent broadcast" do
    sent = start_sending
    RecordingStudioBroadcasts::PublishableWrite.own_write(sent) do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: sent, actor: @admin, attributes: { social_title: "Already sent card" }
      )
    end
    social = "Already sent card"

    update = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: sent, actor: @admin, attributes: { social_title: "Changed in Publishable" }
    )
    transition = RecordingStudioPublishable::Services::Publishables::Transition.call(
      parent_recording: sent, actor: @admin, transition: "unpublish"
    )

    assert_predicate update, :failure?
    assert_equal @message, update.error
    assert_equal [ @message ], update.errors
    assert_predicate transition, :failure?
    assert_equal @message, transition.error
    assert_equal social, sent.reload.current_publishable.social_title
    assert_equal "published", sent.current_publishable.status

    sign_in @admin

    patch "/recordings/#{sent.id}/publishable",
          params: { section: "social", publishable: { social_title: "Changed on the page" } }
    assert_response :see_other
    assert_equal @message, flash[:alert]
    assert_redirected_to "/recordings/#{sent.id}/publishable/social"

    patch "/recordings/#{sent.id}/publishable/draft",
          headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }
    assert_response :unprocessable_content
    assert_includes response.body, @message

    patch "/recordings/#{sent.id}/publishable",
          params: { publishable: { social_title: "Changed as JSON" } },
          as: :json
    assert_response :unprocessable_content
    assert_equal @message, response.parsed_body["error"]

    patch "/recordings/#{sent.id}/publishable/publish", as: :json
    assert_response :unprocessable_content
    assert_equal @message, response.parsed_body["error"]

    error = assert_raises(publishable_api_error) do
      RecordingStudioPublishable::Api::Perform.apply(
        api_context(sent, { social_title: "Changed through the API" }),
        :update_publishable
      )
    end
    publish_error = assert_raises(publishable_api_error) do
      RecordingStudioPublishable::Api::Perform.apply(api_context(sent, {}), :publish)
    end

    assert_equal @message, error.message
    assert_equal @message, publish_error.message
    assert_equal social, sent.reload.current_publishable.social_title
    assert_equal "sending", broadcast_status(sent)
  end

  test "cancel and complete still run after a broadcast has been sent" do
    sending = start_sending(title: "Still going out")
    RecordingStudioBroadcasts.cancel(sending, actor: @admin)

    assert_equal "cancelled", broadcast_status(sending)
    assert_equal "draft", sending.reload.current_publishable.status

    finished = start_sending(title: "Finish the send")
    assert_equal "sending", broadcast_status(finished)
    RecordingStudioBroadcasts::Campaign.complete!(finished, actor: @admin)

    assert_equal "completed", broadcast_status(finished)
    assert_predicate finished.reload.recordable.sent_at, :present?
  end

  test "refusing a transition does not start the nested update" do
    sent = start_sending
    calls = 0
    update = RecordingStudioPublishable::Services::Publishables::Update

    update.stub(:call, ->(*_args, **_kwargs) {
      calls += 1
      RecordingStudio::Services::BaseService::Result.new(success: true)
    }) do
      result = RecordingStudioPublishable::Services::Publishables::Transition.call(
        parent_recording: sent, actor: @admin, transition: "unpublish"
      )

      assert_predicate result, :failure?
      assert_equal @message, result.error
    end
    assert_equal 0, calls
  end

  test "schedule and draft transitions are refused once sent" do
    sent = start_sending

    %w[schedule draft].each do |transition|
      result = RecordingStudioPublishable::Services::Publishables::Transition.call(
        parent_recording: sent, actor: @admin, transition: transition
      )

      assert_predicate result, :failure?
      assert_equal @message, result.error
    end
    assert_equal "published", sent.reload.current_publishable.status
    assert_equal "sending", broadcast_status(sent)
  end

  test "an own write of one broadcast does not unlock another" do
    sent = start_sending
    other = start_sending(title: "Other send")
    result = RecordingStudioBroadcasts::PublishableWrite.own_write(other) do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: sent, actor: @admin, attributes: { social_title: "Unlocked by the other write" }
      )
    end

    assert_predicate result, :failure?
    assert_equal @message, result.error
    assert_nil sent.reload.current_publishable.social_title
  end

  test "an own publishable write is allowed after sent_at is set" do
    sent = start_sending
    result = RecordingStudioBroadcasts::PublishableWrite.own_write(sent) do
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: sent, actor: @admin, attributes: { social_title: "Broadcasts itself" }
      )
    end

    assert_predicate result, :success?
    assert_equal "Broadcasts itself", sent.reload.current_publishable.social_title
  end

  test "edit of a sent broadcast redirects to the index with an alert" do
    sent = start_sending
    sign_in @admin

    get "/admin/broadcasts/#{sent.id}/edit"

    assert_redirected_to "/admin/screens/broadcasts"
    follow_redirect!
    assert_response :success
    assert_includes response.body, @message
    assert_select "h1", text: "Broadcasts"
  end

  test "a viewer is refused the edit page of a sent broadcast" do
    sent = start_sending
    sign_in @viewer

    get "/admin/broadcasts/#{sent.id}/edit"

    assert_response :forbidden
  end

  test "admin update and delete are hidden and refused once sent" do
    sent = start_sending
    perform_enqueued_jobs
    sent.reload
    update = RecordingStudioBroadcasts::BroadcastsResource.action_for(:update)
    delete = RecordingStudioBroadcasts::BroadcastsResource.action_for(:delete)

    refute update.visible?(sent, nil)
    refute delete.visible?(sent, nil)

    sign_in @admin
    get "/admin/broadcasts/#{sent.id}"

    assert_response :success
    assert_select "span[class*='badge-radius']", text: "Sent"
    assert_select "a", text: "Edit", count: 0
    assert_select "a", text: "Delete", count: 0
    assert_includes response.body, "Sent at"
    refute_includes response.body, "Sends at"

    patch "/admin/broadcasts/#{sent.id}", params: { broadcast: { title: "Renamed after send" } }
    assert_response :forbidden
    assert_equal "October update", sent.reload.recordable.title

    delete "/admin/broadcasts/#{sent.id}"
    assert_response :forbidden
    assert RecordingStudio::Recording.exists?(sent.id)
  end

  test "a draft and a scheduled broadcast stay editable" do
    draft = create_broadcast(actor: @admin, title: "Still a draft")
    scheduled = create_broadcast(actor: @admin, title: "Waiting to send")
    RecordingStudioBroadcasts.schedule(scheduled, at: 2.days.from_now, actor: @admin)
    update = RecordingStudioBroadcasts::BroadcastsResource.action_for(:update)
    delete = RecordingStudioBroadcasts::BroadcastsResource.action_for(:delete)

    assert update.visible?(draft, nil)
    assert delete.visible?(draft, nil)
    assert update.visible?(scheduled, nil)
    assert delete.visible?(scheduled, nil)
    assert_nil scheduled.recordable.sent_at

    draft_update = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: draft, actor: @admin, attributes: { social_title: "Draft card" }
    )
    scheduled_update = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: scheduled, actor: @admin, attributes: { social_title: "Scheduled card" }
    )

    assert_predicate draft_update, :success?
    assert_predicate scheduled_update, :success?
    assert_equal "Draft card", draft.reload.current_publishable.social_title
    assert_equal "Scheduled card", scheduled.reload.current_publishable.social_title
    assert_equal "draft", broadcast_status(draft)
    assert_equal "scheduled", broadcast_status(scheduled)

    sign_in @admin
    get "/admin/broadcasts/#{draft.id}/edit"
    assert_response :success
    get "/admin/broadcasts/#{scheduled.id}/edit"
    assert_response :success

    get "/admin/broadcasts/#{draft.id}"
    assert_includes response.body, "Edit"
    assert_includes response.body, "Delete"
    get "/admin/broadcasts/#{scheduled.id}"
    assert_includes response.body, "Edit"
    assert_includes response.body, "Unpublish"
    assert_includes response.body, "Send now"
  end

  private

  def start_sending(title: "October update")
    recording = create_broadcast(actor: @admin, title:)
    RecordingStudioBroadcasts.publish_now(recording, actor: @admin)
    assert_predicate recording.reload.recordable.sent_at, :present?
    recording
  end

  def api_context(recording, params)
    Struct.new(:recording, :api_client, :params, keyword_init: true).new(
      recording: recording, api_client: @admin, params: params
    )
  end

  def publishable_api_error
    if defined?(RecordingStudioApi::InvalidActionInputError)
      RecordingStudioApi::InvalidActionInputError
    else
      StandardError
    end
  end
end
