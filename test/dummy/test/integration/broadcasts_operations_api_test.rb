# frozen_string_literal: true

require "test_helper"

class BroadcastsOperationsApiTest < ActionDispatch::IntegrationTest
  setup do
    reset_tables!
    @admin = create_user("admin@admin.com")
    @viewer = create_user("viewer@example.com")
    assert RecordingStudioAccessible.bootstrap_owner_access!(recording: admin_root_recording, actor: @admin).success?
    assert RecordingStudioAccessible.grant_access(
      recording: admin_root_recording, actor: @viewer, role: "view", manager_actor: @admin
    ).success?
  end

  test "operations API creates, shows, updates, previews, and deletes a campaign" do
    token = operations_token(actor: @admin, role: :admin)

    post operations_path("/broadcasts"),
         headers: json_headers(token),
         params: { title: "October update", subject: "What's new", body: "We shipped broadcasts." }.to_json
    assert_response :created
    payload = json_body
    recording_id = payload.fetch("id")
    assert_equal "October update", payload.fetch("title")
    assert_equal "draft", payload.fetch("status")

    get operations_path("/broadcasts/#{recording_id}"), headers: json_headers(token)
    assert_response :success
    assert_equal "October update", json_body.fetch("title")

    patch operations_path("/broadcasts/#{recording_id}"),
          headers: json_headers(token),
          params: { subject: "Still new" }.to_json
    assert_response :success
    assert_equal "Still new", json_body.fetch("subject")

    post operations_path("/broadcasts/#{recording_id}/actions/preview"), headers: json_headers(token)
    assert_response :success
    assert_equal %w[matching eligible excluded].sort, json_body.keys.sort

    delete operations_path("/broadcasts/#{recording_id}"), headers: json_headers(token)
    assert_response :no_content
    assert_equal 0, RecordingStudioBroadcasts::Campaign.recordings(admin_root_recording).count
  end

  test "operations API test-sends and sends through campaign methods" do
    token = operations_token(actor: @admin, role: :admin)
    recording = create_broadcast(actor: @admin)

    post operations_path("/broadcasts/#{recording.id}/actions/test_send"), headers: json_headers(token)
    assert_response :success
    assert_equal "draft", broadcast_status(recording)

    perform_enqueued_jobs do
      post operations_path("/broadcasts/#{recording.id}/actions/send"), headers: json_headers(token)
    end
    assert_response :success
    assert_includes %w[sending completed], broadcast_status(recording)
  end

  test "operations API schedules, unpublishes, and cancels through campaign methods" do
    token = operations_token(actor: @admin, role: :admin)
    recording = create_broadcast(actor: @admin)

    post operations_path("/broadcasts/#{recording.id}/actions/schedule"),
         headers: json_headers(token),
         params: { scheduled_at: 2.days.from_now.iso8601 }.to_json
    assert_response :success
    assert_equal "scheduled", broadcast_status(recording)

    post operations_path("/broadcasts/#{recording.id}/actions/unpublish"), headers: json_headers(token)
    assert_response :success
    assert_equal "draft", broadcast_status(recording)

    post operations_path("/broadcasts/#{recording.id}/actions/schedule"),
         headers: json_headers(token),
         params: { scheduled_at: 3.days.from_now.iso8601 }.to_json
    post operations_path("/broadcasts/#{recording.id}/actions/cancel"), headers: json_headers(token)
    assert_response :success
    assert_equal "cancelled", broadcast_status(recording)
  end

  test "a viewer token can read and preview but cannot write or send" do
    recording = create_broadcast(actor: @admin)
    token = operations_token(actor: @admin, role: :view)

    get operations_path("/broadcasts/#{recording.id}"), headers: json_headers(token)
    assert_response :success

    post operations_path("/broadcasts/#{recording.id}/actions/preview"), headers: json_headers(token)
    assert_response :success

    post operations_path("/broadcasts"),
         headers: json_headers(token),
         params: { title: "Nope", subject: "Nope" }.to_json
    assert_response :forbidden

    post operations_path("/broadcasts/#{recording.id}/actions/send"), headers: json_headers(token)
    assert_response :forbidden
  end

  test "broadcasts stay off the public API" do
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudioBroadcasts::Broadcast")

    assert_equal false, registration.auto_capability_actions
    assert_empty registration.capability_actions
    assert_equal RecordingStudioBroadcasts::Api::Closed,
                 RecordingStudioApi.resource_handler("RecordingStudioBroadcasts::Broadcast", :create)
    refute_includes RecordingStudioApi.capability_actions_for("RecordingStudioBroadcasts::Broadcast").map(&:name), "publish"
    refute_includes RecordingStudioApi.capability_actions_for("RecordingStudioBroadcasts::Broadcast").map(&:name), "send"
  end

  test "operations member actions keep admin-screen roles" do
    assert_equal :admin, RecordingStudioApi.capability_action(:send, api: :operations).required_role
    assert_equal :admin, RecordingStudioApi.capability_action(:schedule, api: :operations).required_role
    assert_equal :admin, RecordingStudioApi.capability_action(:cancel, api: :operations).required_role
    assert_equal :admin, RecordingStudioApi.capability_action(:test_send, api: :operations).required_role
    assert_equal :view, RecordingStudioApi.capability_action(:preview, api: :operations).required_role
    assert_equal :edit, RecordingStudioApi.capability_action(:unpublish, api: :operations).required_role
  end

  private

  def operations_path(suffix)
    "/recording_studio_api/apis/operations/v1#{suffix}"
  end

  def json_headers(token)
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  def operations_token(actor:, role:)
    result = RecordingStudioApi::Services::IssueTestCredential.call(
      api: :operations,
      actor: actor,
      access_point_recording: admin_root_recording,
      role: role,
      name: "broadcasts-operations-#{role}"
    )
    flunk(result.error.inspect) unless result.success?

    result.value.fetch(:access_token)
  end
end
