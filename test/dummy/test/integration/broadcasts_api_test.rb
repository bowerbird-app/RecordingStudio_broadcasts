# frozen_string_literal: true

require "test_helper"

class BroadcastsApiTest < ActionDispatch::IntegrationTest
  OPERATIONS = "/recording_studio_api/apis/operations/v1"
  PUBLIC_API = "/recording_studio_api/api/v1"

  setup do
    reset_tables!
    @admin = create_user("admin@admin.com")
    @viewer = create_user("viewer@example.com")
    assert RecordingStudioAccessible.bootstrap_owner_access!(recording: admin_root_recording, actor: @admin).success?
    assert RecordingStudioAccessible.grant_access(
      recording: admin_root_recording, actor: @viewer, role: "view", manager_actor: @admin
    ).success?
    @admin_token = issue_token(role: :admin)
    @viewer_token = issue_token(role: :view)
  end

  test "operations CRUD matches admin roles" do
    get "#{OPERATIONS}/broadcasts", headers: bearer(@admin_token)
    assert_response :success
    assert_empty json_body.fetch("records")

    post "#{OPERATIONS}/broadcasts",
         params: { title: "October update", subject: "What's new", body: "We shipped broadcasts." },
         as: :json,
         headers: bearer(@admin_token)
    assert_response :created
    recording_id = json_body.fetch("id")
    assert_equal "draft", json_body.fetch("status")

    get "#{OPERATIONS}/broadcasts/#{recording_id}", headers: bearer(@viewer_token)
    assert_response :success
    assert_equal "October update", json_body.fetch("title")

    patch "#{OPERATIONS}/broadcasts/#{recording_id}",
          params: { body: "Updated body" },
          as: :json,
          headers: bearer(@viewer_token)
    assert_response :forbidden

    patch "#{OPERATIONS}/broadcasts/#{recording_id}",
          params: { body: "Updated body" },
          as: :json,
          headers: bearer(@admin_token)
    assert_response :success
    assert_equal "Updated body", json_body.fetch("body")
  end

  test "unauthenticated and public tokens cannot use operations broadcasts" do
    get "#{OPERATIONS}/broadcasts"
    assert_response :unauthorized

    get "#{PUBLIC_API}/broadcasts", headers: bearer(@admin_token)
    assert_response :unauthorized
    assert_nil RecordingStudioApi.recordable_registration_for(
      "RecordingStudioBroadcasts::Broadcast", api: :public
    )
    registration = RecordingStudioApi.recordable_registration_for(
      "RecordingStudioBroadcasts::Broadcast", api: :operations
    )
    assert_equal false, registration.auto_capability_actions
    refute_includes RecordingStudioApi.capability_actions_for(
      "RecordingStudioBroadcasts::Broadcast", api: :operations
    ).map(&:name), "publish"
  end

  test "view can preview and cannot send" do
    recording = create_broadcast(actor: @admin)

    get "#{OPERATIONS}/broadcasts/#{recording.id}/actions/preview", headers: bearer(@viewer_token)
    assert_response :success
    assert json_body.key?("matching")

    post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/send", headers: bearer(@viewer_token)
    assert_response :forbidden
    assert_equal "draft", broadcast_status(recording)
  end

  test "admin send schedule unpublish cancel and test send use campaign methods" do
    recording = create_broadcast(actor: @admin)

    post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/test_send", headers: bearer(@admin_token)
    assert_response :success
    assert_equal "draft", json_body.fetch("status")

    at = 2.days.from_now.utc.iso8601
    post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/schedule",
         params: { scheduled_at: at },
         as: :json,
         headers: bearer(@admin_token)
    assert_response :success
    assert_equal "scheduled", json_body.fetch("status")

    post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/unpublish", headers: bearer(@admin_token)
    assert_response :success
    assert_equal "draft", json_body.fetch("status")

    post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/cancel", headers: bearer(@admin_token)
    assert_response :success
    assert_equal "cancelled", json_body.fetch("status")
  end

  test "send now goes through publish_now not generic publish" do
    recording = create_broadcast(actor: @admin)

    post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/publish", headers: bearer(@admin_token)
    assert_response :unprocessable_entity

    perform_enqueued_jobs do
      post "#{OPERATIONS}/broadcasts/#{recording.id}/actions/send", headers: bearer(@admin_token)
    end
    assert_response :success
    assert_includes %w[sending completed], json_body.fetch("status")
  end

  test "destroy uses campaign and a second admin root is not readable" do
    recording = create_broadcast(actor: @admin)
    other_root = RecordingStudio.root_recording_for(AdminRoot.create!(name: "Other"))
    other = RecordingStudioBroadcasts::Campaign.create(
      other_root, actor: @admin, title: "Other", subject: "Other", body: "Nope"
    )

    get "#{OPERATIONS}/broadcasts/#{other.id}", headers: bearer(@admin_token)
    assert_response :not_found

    delete "#{OPERATIONS}/broadcasts/#{recording.id}", headers: bearer(@admin_token)
    assert_response :success
    assert json_body.fetch("deleted")
  end

  private

  def issue_token(role:)
    issued = RecordingStudioApi::Services::IssueTestCredential.call(
      api: :operations,
      actor: @admin,
      access_point_recording: admin_root_recording,
      role: role
    )
    raise issued.error unless issued.success?

    issued.value.fetch(:access_token)
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end
