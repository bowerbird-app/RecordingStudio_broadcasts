# frozen_string_literal: true

class CreateRecordingStudioBroadcasts < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :recording_studio_broadcasts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :title, null: false
      t.string :subject, null: false
      t.text :body, null: false, default: ""
      t.jsonb :filter_params, null: false, default: {}
      t.datetime :scheduled_at
      t.string :status, null: false, default: "draft"
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.check_constraint "status IN ('draft', 'scheduled', 'sending', 'completed', 'cancelled')",
                         name: "rs_broadcasts_status"
      t.check_constraint "status <> 'scheduled' OR scheduled_at IS NOT NULL", name: "rs_broadcasts_scheduled_at"
    end
  end
end
