# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module BroadcastTestHelpers
  def admin_root_recording
    @admin_root_recording ||= RecordingStudio.root_recording_for(AdminRoot.create!(name: "Admin"))
  end

  def create_user(email, created_at: Time.current)
    User.create!(email: email, password: "Password", password_confirmation: "Password", created_at: created_at)
  end

  def create_broadcast(actor: nil, **attributes)
    RecordingStudioBroadcasts::Campaign.create(
      admin_root_recording,
      actor: actor,
      title: "October update",
      subject: "What's new in October",
      body: "We shipped broadcasts.",
      **attributes
    )
  end

  def broadcast_status(recording)
    recording.reload.recordable.status
  end

  def reset_tables!
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(", ")} CASCADE")
  end
end

ActiveSupport::TestCase.include ActionMailer::TestHelper
ActiveSupport::TestCase.include BroadcastTestHelpers
