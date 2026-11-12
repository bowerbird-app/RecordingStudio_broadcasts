# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ApiTest < Minitest::Test
  FakeRecording = Struct.new(:id, :recordable_type, :title, :subject, :body, :status, :scheduled_at, :sent_at,
                             :filter_params, keyword_init: true) do
    def reload
      self
    end
  end

  FakeGrant = Struct.new(:actor, :scope_recording, :role, keyword_init: true) do
    def authorize!(recording:, role:)
      raise RecordingStudioApi::AuthorizationError unless allowed?(role)

      recording
    end

    def allowed?(required)
      order = { view: 0, edit: 1, admin: 2 }
      order.fetch(role) >= order.fetch(required)
    end
  end

  FakeContext = Struct.new(:access_grant, :actor, :root_recording, :recording, :id, :parent_id, :params,
                           :request_params, :scoped_recordings, :api_key, :api_version, keyword_init: true)

  def test_register_is_skipped_when_the_api_gem_is_missing
    RecordingStudioBroadcasts::Api.stub(:recording_studio_api_available?, false) do
      refute RecordingStudioBroadcasts::Api.register!
    end
  end

  def test_operations_type_is_closed_on_the_public_api
    RecordingStudioApi.configure { |config| config.api :operations }
    assert RecordingStudioBroadcasts::Api.register!

    public_registration = RecordingStudioApi.recordable_registration_for(
      RecordingStudioBroadcasts::Api::RECORDABLE_TYPE
    )
    operations_registration = RecordingStudioApi.recordable_registration_for(
      RecordingStudioBroadcasts::Api::RECORDABLE_TYPE,
      api: :operations
    )

    assert_equal false, public_registration.auto_capability_actions
    assert_empty public_registration.capability_actions
    assert_equal RecordingStudioBroadcasts::Api::Closed,
                 RecordingStudioApi.resource_handler(RecordingStudioBroadcasts::Api::RECORDABLE_TYPE, :create)
    assert operations_registration.supports_operation?(:index)
    assert operations_registration.supports_operation?(:create)
    assert_equal false, operations_registration.auto_capability_actions
    %w[send schedule unpublish cancel test_send preview].each do |action|
      assert_includes operations_registration.capability_actions, action
    end
    refute_includes operations_registration.capability_actions, "publish"
  end

  def test_member_action_roles_match_the_admin_screens
    RecordingStudioApi.configure { |config| config.api :operations }
    RecordingStudioBroadcasts::Api.register!

    assert_equal :admin, RecordingStudioApi.capability_action(:send, api: :operations).required_role
    assert_equal :admin, RecordingStudioApi.capability_action(:schedule, api: :operations).required_role
    assert_equal :admin, RecordingStudioApi.capability_action(:cancel, api: :operations).required_role
    assert_equal :admin, RecordingStudioApi.capability_action(:test_send, api: :operations).required_role
    assert_equal :view, RecordingStudioApi.capability_action(:preview, api: :operations).required_role
  end

  def test_send_calls_publish_now
    recording = broadcast_recording
    actor = Object.new
    grant = FakeGrant.new(actor: actor, scope_recording: Object.new, role: :admin)
    context = FakeContext.new(access_grant: grant, actor: actor, recording: recording, params: {})
    called = false

    RecordingStudioBroadcasts.stub(:publish_now, lambda { |found, **kwargs|
      called = true
      assert_equal recording, found
      assert_equal actor, kwargs[:actor]
      found
    }) do
      assert_equal recording, RecordingStudioBroadcasts::Api::Send.call(context)
      assert called
    end
  end

  def test_schedule_passes_the_clock
    recording = broadcast_recording
    actor = Object.new
    at = Time.zone.parse("2026-12-01 10:00:00")
    grant = FakeGrant.new(actor: actor, scope_recording: Object.new, role: :admin)
    context = FakeContext.new(
      access_grant: grant, actor: actor, recording: recording,
      params: { scheduled_at: at.iso8601 }
    )

    RecordingStudioBroadcasts.stub(:schedule, lambda { |found, **kwargs|
      assert_equal recording, found
      assert_in_delta at, kwargs[:at], 1
      found
    }) do
      assert_equal recording, RecordingStudioBroadcasts::Api::Schedule.call(context)
    end
  end

  def test_unpublish_requires_admin_and_returns_json
    recording = broadcast_recording
    actor = Object.new
    grant = FakeGrant.new(actor: actor, scope_recording: Object.new, role: :admin)
    context = FakeContext.new(access_grant: grant, actor: actor, recording: recording, api_key: :operations,
                              api_version: "v1", params: {})

    RecordingStudioBroadcasts.stub(:unpublish, ->(found, **) { found }) do
      RecordingStudioApi::Serializers::ResourceRecordingSerializer.stub(:call, { "id" => recording.id }) do
        result = RecordingStudioBroadcasts::Api::Unpublish.call(context)

        assert_equal :ok, result[:status]
        assert_equal({ "id" => recording.id }, result[:json])
      end
    end
  end

  def test_preview_returns_audience_counts
    recording = broadcast_recording
    grant = FakeGrant.new(actor: :viewer, scope_recording: Object.new, role: :view)
    context = FakeContext.new(access_grant: grant, recording: recording, params: {})
    counts = { matching: 3, eligible: 1, excluded: 2 }

    RecordingStudioBroadcasts.stub(:preview, ->(found) { counts if found.equal?(recording) }) do
      assert_equal counts, RecordingStudioBroadcasts::Api::Preview.call(context)
    end
  end

  def test_invalid_transition_becomes_api_input_error
    recording = broadcast_recording
    grant = FakeGrant.new(actor: :admin, scope_recording: Object.new, role: :admin)
    context = FakeContext.new(access_grant: grant, actor: :admin, recording: recording, params: {})

    boom = proc { raise RecordingStudioBroadcasts::InvalidTransition, "A completed broadcast cannot be send" }
    RecordingStudioBroadcasts.stub(:publish_now, boom) do
      error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
        RecordingStudioBroadcasts::Api::Send.call(context)
      end
      assert_equal "A completed broadcast cannot be send", error.message
    end
  end

  def test_broadcast_serializer_emits_json_safe_timestamps
    recording = Struct.new(:title, :subject, :body, :status, :scheduled_at, :sent_at, :filter_params).new(
      "October", "News", "Shipped.", "scheduled", Time.utc(2026, 12, 1, 10, 0, 0), nil, { "plan" => "pro" }
    )
    payload = RecordingStudioBroadcasts::Api::Serialize::BROADCAST.call(recording)

    assert_equal "2026-12-01T10:00:00Z", payload[:scheduled_at]
    assert_nil payload[:sent_at]
    assert_equal({ "plan" => "pro" }, payload[:filter_params])
  end

  private

  def broadcast_recording
    FakeRecording.new(
      id: "broadcast-1",
      recordable_type: RecordingStudioBroadcasts::Api::RECORDABLE_TYPE,
      title: "October",
      subject: "News",
      body: "Shipped.",
      status: "draft",
      scheduled_at: nil,
      sent_at: nil,
      filter_params: {}
    )
  end
end
