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
    assert_includes response.body, "Product updates sent by email"
    assert_includes response.body, "New broadcast"
    assert_includes response.body, "@hotwired/turbo-rails"
    assert_includes response.body, "controllers/recording_studio_admin/screen_filters_controller"

    get "/admin/broadcasts/new"
    assert_response :success
    assert_select "textarea[name='broadcast[body]']" do |nodes|
      classes = nodes.first["class"].to_s
      refute_includes classes, "rounded-full"
      assert_includes classes, "rounded-[var(--form-control-radius)]"
    end

    get "/admin/screens/broadcasts/table"
    assert_response :success
    assert_includes response.body, "No data available"
    refute_includes response.body, "Write a product update, choose who should get it"
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
    assert_select "dt", text: "Matching"
    assert_select "dd", text: "3"
    assert_select "dt", text: "Ready"
    assert_select "dd", text: "3"
    assert_select "dt", text: "Left out"
    assert_select "dd", text: "0"

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
    assert_select "dt", text: "Sent"
    assert_select "dd", text: "3"
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
    assert_select "a.underline[href='/admin/broadcasts/#{recording.id}']"

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
    assert_select "span[class*='badge-radius']", text: "Scheduled", count: 1
    assert_includes response.body, "Sends at"
    assert_includes response.body, "October 24, 2026 15:00"
    assert_includes response.body, "Unpublish"
    assert_includes response.body, "Send now"
    assert_includes response.body, "Schedule"

    sent = create_broadcast(actor: @admin, title: "Already sent")
    perform_enqueued_jobs { RecordingStudioBroadcasts.publish_now(sent, actor: @admin) }

    get "/admin/broadcasts/#{sent.id}"

    assert_select "span[class*='badge-radius']", text: "Sent", count: 1
    assert_includes response.body, "Sent at"
    refute_includes response.body, "Sends at"
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

    context = RecordingStudioAdmin::Context.new(current_actor: @admin)
    recordings = RecordingStudioBroadcasts::BroadcastsScreen.query.call(context).to_a

    assert_no_queries do
      recordings.each { |recording| RecordingStudioBroadcasts::BroadcastsHelper.schedule_text(recording) }
    end
    assert_includes recordings.map { |recording| RecordingStudioBroadcasts::BroadcastsHelper.schedule_text(recording) }.join,
                    "Scheduled"
  end

  test "a sent broadcast's public page reveals no title or uuid" do
    recording = create_broadcast(actor: @admin, title: "Secret launch title")
    perform_enqueued_jobs { RecordingStudioBroadcasts.publish_now(recording, actor: @admin) }
    publishable = recording.reload.current_publishable
    child = recording.publishable_child_recording

    get "/published/#{child.id}/#{publishable.slug}"

    assert_response :success
    assert_includes response.body, '<meta name="robots" content="noindex">'
    assert_equal "", response.body.sub("<meta name=\"robots\" content=\"noindex\">", "").strip
    refute_includes response.body, "Secret launch title"
    refute_includes response.body, child.id
    refute_includes response.body, recording.id
  end

  test "the show page names who changed the send time in Publishable" do
    recording = create_broadcast(actor: @admin)
    editor = create_user("cara@example.com")
    RecordingStudioBroadcasts.schedule(recording, at: 2.hours.from_now, actor: @admin)
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: editor,
      attributes: {
        status: "scheduled",
        publish_at: 4.hours.from_now.utc.iso8601,
        time_zone: Time.zone.tzinfo.name
      }
    )
    sign_in @admin

    get "/admin/broadcasts/#{recording.id}"

    assert_response :success
    assert_includes response.body, "Returned to draft: send time changed in Publishable by cara@example.com"
  end

  test "the show title uses the same page title as the broadcasts index" do
    recording = create_broadcast(actor: @admin, title: "Still writing")
    sign_in @admin

    get "/admin/screens/broadcasts"
    assert_select "h1", text: "Broadcasts" do |nodes|
      @index_class = nodes.first["class"]
      @index_style = nodes.first["style"]
    end

    get "/admin/broadcasts/#{recording.id}"
    assert_select "h1", text: "Still writing" do |nodes|
      assert_equal @index_class, nodes.first["class"]
      assert_equal @index_style, nodes.first["style"]
    end
    assert_select "h1", text: "Still writing" do |headings|
      row = headings.first
      row = row.parent until row.nil? || badge_sits_beside_title?(row)
      assert row
      heading = row.element_children.find { |child| child.css("h1").any? }
      badge = row.element_children.find { |child| child.text.include?("Draft") && child.css("h1").empty? }
      assert heading
      assert badge
      assert_operator row.element_children.index(heading), :<, row.element_children.index(badge)
    end
  end

  test "an admin deletes a draft" do
    recording = create_broadcast(actor: @admin)
    sign_in @admin

    delete "/admin/broadcasts/#{recording.id}"

    assert_redirected_to "/admin/screens/broadcasts"
    assert_not RecordingStudio::Recording.exists?(recording.id)
  end

  private

  def badge_sits_beside_title?(row)
    children = row.element_children
    children.any? { |child| child.css("h1").any? } &&
      children.any? { |child| child.text.include?("Draft") && child.css("h1").empty? }
  end
end
