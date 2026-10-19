# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class BroadcastsAdminTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    reset_tables!
    @admin = create_user("admin@admin.com")
    @viewer = create_user("viewer@example.com")
    assert RecordingStudioAccessible.bootstrap_owner_access!(recording: admin_root_recording, actor: @admin).success?
    assert RecordingStudioAccessible.grant_access(
      recording: admin_root_recording, actor: @viewer, role: "view", manager_actor: @admin
    ).success?
  end

  test "the broadcasts screen says when there are none" do
    sign_in @admin

    get "/admin/screens/broadcasts"

    assert_response :success
    assert_includes response.body, "No broadcasts yet."
    assert_includes response.body, "New broadcast"
    assert_includes response.body, "@hotwired/turbo-rails"
    assert_includes response.body, "controllers/recording_studio_admin/screen_filters_controller"

    get "/admin/screens/broadcasts/table"
    assert_response :success
    assert_includes response.body, "Write a product update, choose who should get it"
    refute_includes response.body, "No data available"
  end

  test "an admin creates a broadcast, sees who gets it, tests it, and sends it" do
    create_user("early@example.com", created_at: 90.days.ago)
    create_user("recent@example.com", created_at: 2.days.ago)
    sign_in @admin

    post "/admin/broadcasts", params: { broadcast: {
      title: "October update", subject: "What's new", body: "We shipped broadcasts.",
      filter_params: { registered_after: 30.days.ago.to_date.iso8601 }
    } }
    recording = RecordingStudioBroadcasts::Campaign.recordings(admin_root_recording).sole
    assert_redirected_to "/admin/broadcasts/#{recording.id}"

    follow_redirect!
    assert_includes response.body, "Saved."
    assert_select "tr", text: /Matching\s*3/
    assert_select "tr", text: /Ready\s*3/
    assert_select "tr", text: /Left out\s*0/

    assert_emails 1 do
      post "/admin/broadcasts/#{recording.id}/test_send"
    end
    assert_equal [ "admin@admin.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal "draft", broadcast_status(recording)
    follow_redirect!
    assert_includes response.body, "Test sent to you."

    assert_no_emails { post "/admin/broadcasts/#{recording.id}/test_send" }
    follow_redirect!
    assert_includes response.body, "You already got a test of this broadcast."

    assert_emails 3 do
      perform_enqueued_jobs { post "/admin/broadcasts/#{recording.id}/send_message" }
    end
    assert_equal %w[admin@admin.com recent@example.com viewer@example.com],
                 ActionMailer::Base.deliveries.last(3).flat_map(&:to).sort
    assert_equal "completed", broadcast_status(recording)

    follow_redirect!
    assert_select "tr", text: /Sent\s*3/
    refute_includes response.body, "Send now"
  end

  test "a viewer can open broadcasts but cannot send one" do
    recording = create_broadcast(actor: @admin)
    sign_in @viewer

    get "/admin/screens/broadcasts"
    assert_response :success
    refute_includes response.body, "New broadcast"

    get "/admin/screens/broadcasts/table"
    assert_response :success
    assert_includes response.body, "October update"
    assert_select "a[href='/admin/broadcasts/#{recording.id}']"

    get "/admin/broadcasts/#{recording.id}"
    assert_response :success
    refute_includes response.body, "Send now"

    assert_no_emails do
      assert_no_enqueued_jobs { post "/admin/broadcasts/#{recording.id}/send_message" }
    end
    assert_response :forbidden
    assert_equal "draft", broadcast_status(recording)
  end

  test "someone without access cannot open broadcasts" do
    sign_in create_user("stranger@example.com")

    get "/admin/screens/broadcasts"

    assert_response :forbidden
  end

  test "scheduling without a time asks for one" do
    recording = create_broadcast(actor: @admin)
    sign_in @admin

    assert_no_enqueued_jobs { post "/admin/broadcasts/#{recording.id}/schedule", params: { scheduled_at: "" } }

    follow_redirect!
    assert_includes response.body, "Pick a time to send it."
    assert_equal "draft", broadcast_status(recording)
  end

  test "the show page names a scheduled send and a sent one" do
    sign_in @admin
    scheduled = create_broadcast(actor: @admin, title: "October 24 send")
    at = Time.zone.parse("2026-10-24 15:00")
    RecordingStudioBroadcasts.schedule(scheduled, at:, actor: @admin)

    get "/admin/broadcasts/#{scheduled.id}"

    assert_response :success
    assert_includes response.body, "Scheduled"
    assert_includes response.body, "October 24, 2026 15:00"
    assert_includes response.body, "Unpublish"
    assert_includes response.body, "Send now"

    sent = create_broadcast(actor: @admin, title: "Already sent")
    perform_enqueued_jobs { RecordingStudioBroadcasts.publish_now(sent, actor: @admin) }

    get "/admin/broadcasts/#{sent.id}"

    assert_includes response.body, "Sent"
    assert_includes response.body, I18n.l(sent.reload.recordable.sent_at.in_time_zone, format: :long)
  end

  test "a draft's delete action is offered with the other actions" do
    recording = create_broadcast(actor: @admin)
    sign_in @admin

    get "/admin/broadcasts/#{recording.id}"

    assert_response :success
    assert_includes response.body, "Delete"
    assert_includes response.body, "Send now"
    assert_includes response.body, "Edit"
  end

  test "the broadcasts table reads each publishable from the preloaded association" do
    2.times do |index|
      recording = create_broadcast(actor: @admin, title: "Scheduled #{index}")
      RecordingStudioBroadcasts.schedule(recording, at: (index + 1).hours.from_now, actor: @admin)
    end

    recordings = RecordingStudioBroadcasts::Campaign.recordings(admin_root_recording)
                                                    .includes(:recordable)
                                                    .preload(child_recordings: :recordable)
                                                    .to_a

    assert_no_queries do
      recordings.each { |recording| RecordingStudioBroadcasts::BroadcastsHelper.schedule_text(recording) }
    end
    assert_includes recordings.map { |recording| RecordingStudioBroadcasts::BroadcastsHelper.schedule_text(recording) }.join,
                    "Scheduled"
  end

  test "an admin deletes a draft" do
    recording = create_broadcast(actor: @admin)
    sign_in @admin

    delete "/admin/broadcasts/#{recording.id}"

    assert_redirected_to "/admin/screens/broadcasts"
    assert_not RecordingStudio::Recording.exists?(recording.id)
  end
end
