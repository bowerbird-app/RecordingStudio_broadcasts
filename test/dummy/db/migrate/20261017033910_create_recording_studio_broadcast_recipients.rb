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

      t.check_constraint "status IN ('pending', 'sending', 'sent', 'skipped', 'failed')",
                         name: "rs_broadcast_recipients_status"
      t.check_constraint "skip_reason IS NULL OR skip_reason IN ('preference', 'suppressed', 'cancelled')",
                         name: "rs_broadcast_recipients_skip_reason"
      t.check_constraint "status <> 'skipped' OR skip_reason IS NOT NULL", name: "rs_broadcast_recipients_skipped"
      t.check_constraint "status <> 'sending' OR claimed_at IS NOT NULL", name: "rs_broadcast_recipients_sending"
      t.check_constraint "status <> 'sent' OR notification_id IS NOT NULL", name: "rs_broadcast_recipients_sent"
    end

    add_index :recording_studio_broadcast_recipients, %i[recording_id recipient_type recipient_id],
              unique: true, name: "idx_rs_broadcast_recipients_unique"
    add_index :recording_studio_broadcast_recipients, %i[recording_id status],
              name: "idx_rs_broadcast_recipients_status"
  end
end
