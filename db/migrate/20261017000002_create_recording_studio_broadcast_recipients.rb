# frozen_string_literal: true

class CreateRecordingStudioBroadcastRecipients < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_broadcast_recipients, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :recording_id, null: false
      t.uuid :root_recording_id, null: false
      t.string :recipient_type, null: false
      t.uuid :recipient_id, null: false
      t.string :status, null: false, default: "pending"
      t.string :skip_reason
      t.uuid :notification_id
      t.datetime :claimed_at

      t.timestamps
    end

    add_index :recording_studio_broadcast_recipients, %i[recording_id recipient_type recipient_id],
              unique: true, name: "idx_rs_broadcast_recipients_unique"
    add_index :recording_studio_broadcast_recipients, %i[recording_id status],
              name: "idx_rs_broadcast_recipients_status"
  end
end
