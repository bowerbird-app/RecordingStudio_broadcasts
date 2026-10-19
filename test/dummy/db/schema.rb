# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_060011) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "action_mailbox_inbound_emails", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_roots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "folders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "recording_studio_access_constraints", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "allowed_audiences", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_recording_studio_access_constraints_on_action"
  end

  create_table "recording_studio_access_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "recording_id", null: false
    t.string "email", null: false
    t.string "role", null: false
    t.string "token_digest", limit: 64, null: false
    t.string "manager_actor_type", null: false
    t.uuid "manager_actor_id", null: false
    t.string "accepted_by_actor_type"
    t.uuid "accepted_by_actor_id"
    t.datetime "expires_at", null: false
    t.datetime "last_sent_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id", "email"], name: "idx_rs_access_invitations_one_active", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["recording_id"], name: "index_recording_studio_access_invitations_on_recording_id"
    t.index ["token_digest"], name: "idx_rs_access_invitations_token_digest", unique: true
    t.check_constraint "accepted_at IS NULL OR revoked_at IS NULL", name: "access_invitations_not_accepted_and_revoked"
  end

  create_table "recording_studio_access_request_intents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "recording_id", null: false
    t.uuid "user_id", null: false
    t.uuid "otp_challenge_id", null: false
    t.string "email", null: false
    t.string "role"
    t.string "action"
    t.datetime "expires_at", null: false
    t.datetime "fulfilled_at"
    t.datetime "created_at", null: false
    t.string "submitted_name"
    t.index ["recording_id"], name: "index_recording_studio_access_request_intents_on_recording_id"
    t.check_constraint "action IS NULL OR char_length(action::text) <= 120", name: "recording_studio_access_request_intents_action_length"
    t.check_constraint "char_length(email::text) <= 255", name: "recording_studio_access_request_intents_email_length"
    t.check_constraint "submitted_name IS NULL OR char_length(submitted_name::text) <= 120", name: "recording_studio_access_request_intents_name_length"
  end

  create_table "recording_studio_access_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor_type", null: false
    t.uuid "actor_id", null: false
    t.string "role"
    t.string "action"
    t.text "message"
    t.string "status", default: "pending", null: false
    t.uuid "access_recording_id"
    t.text "review_note"
    t.datetime "created_at", null: false
    t.jsonb "gate_metadata", default: {}, null: false
    t.uuid "target_recording_id", null: false
    t.string "pending_key"
    t.index ["actor_type", "actor_id"], name: "index_recording_studio_access_requests_on_actor"
    t.index ["pending_key"], name: "index_recording_studio_access_requests_one_pending", unique: true, where: "(pending_key IS NOT NULL)"
    t.check_constraint "action IS NULL OR char_length(action::text) <= 120", name: "recording_studio_access_requests_action_length"
    t.check_constraint "message IS NULL OR char_length(message) <= 2000", name: "recording_studio_access_requests_message_length"
    t.check_constraint "review_note IS NULL OR char_length(review_note) <= 2000", name: "recording_studio_access_requests_note_length"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'denied'::character varying]::text[])", name: "recording_studio_access_requests_status"
  end

  create_table "recording_studio_access_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "audience", null: false
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_recording_studio_access_rules_on_action"
  end

  create_table "recording_studio_accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.uuid "depends_on_recording_id"
    t.string "role", default: "view", null: false
    t.index ["actor_type", "actor_id", "role"], name: "index_recording_studio_accesses_on_actor_and_role"
    t.index ["actor_type", "actor_id"], name: "index_recording_studio_accesses_on_actor"
    t.index ["depends_on_recording_id"], name: "index_recording_studio_accesses_on_depends_on_recording_id"
  end

  create_table "recording_studio_broadcast_recipients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "recording_id", null: false
    t.uuid "root_recording_id", null: false
    t.string "recipient_type", null: false
    t.uuid "recipient_id", null: false
    t.string "status", default: "pending", null: false
    t.string "skip_reason"
    t.uuid "notification_id"
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id", "recipient_type", "recipient_id"], name: "idx_rs_broadcast_recipients_unique", unique: true
    t.index ["recording_id", "status"], name: "idx_rs_broadcast_recipients_status"
    t.check_constraint "skip_reason IS NULL OR (skip_reason::text = ANY (ARRAY['preference'::character varying::text, 'suppressed'::character varying::text, 'cancelled'::character varying::text]))", name: "rs_broadcast_recipients_skip_reason"
    t.check_constraint "status::text <> 'sending'::text OR claimed_at IS NOT NULL", name: "rs_broadcast_recipients_sending"
    t.check_constraint "status::text <> 'sent'::text OR notification_id IS NOT NULL", name: "rs_broadcast_recipients_sent"
    t.check_constraint "status::text <> 'skipped'::text OR skip_reason IS NOT NULL", name: "rs_broadcast_recipients_skipped"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'sending'::character varying::text, 'sent'::character varying::text, 'skipped'::character varying::text, 'failed'::character varying::text])", name: "rs_broadcast_recipients_status"
  end

  create_table "recording_studio_broadcasts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "subject", null: false
    t.text "body", default: "", null: false
    t.jsonb "filter_params", default: {}, null: false
    t.datetime "scheduled_at"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "sent_at"
    t.check_constraint "status::text <> 'scheduled'::text OR scheduled_at IS NOT NULL", name: "rs_broadcasts_scheduled_at"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'scheduled'::character varying::text, 'sending'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text])", name: "rs_broadcasts_status"
  end

  create_table "recording_studio_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.uuid "impersonator_id"
    t.string "impersonator_type"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.uuid "previous_recordable_id"
    t.string "previous_recordable_type"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "recording_id", null: false
    t.index ["action", "occurred_at"], name: "index_rs_events_on_action_and_occurred_at"
    t.index ["actor_type", "actor_id", "occurred_at"], name: "index_rs_events_on_actor_and_occurred_at"
    t.index ["recording_id", "idempotency_key"], name: "index_recording_studio_events_on_recording_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["recording_id", "occurred_at", "created_at"], name: "index_rs_events_on_recording_and_timeline", order: { occurred_at: :desc, created_at: :desc }
    t.index ["recording_id"], name: "index_recording_studio_events_on_recording_id"
  end

  create_table "recording_studio_notifications_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "notification_id", null: false
    t.string "channel", null: false
    t.string "status", default: "pending", null: false
    t.datetime "delivered_at"
    t.text "error_message"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "rollup_reserved_at"
    t.index ["channel", "status"], name: "idx_rsn_deliveries_channel_status"
    t.index ["notification_id", "channel"], name: "idx_rsn_deliveries_notification_channel", unique: true
    t.index ["status", "rollup_reserved_at"], name: "idx_rsn_deliveries_rollup_reservation"
  end

  create_table "recording_studio_notifications_email_suppressions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address", null: false
    t.string "reason", null: false
    t.string "provider", null: false
    t.datetime "lifted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "idx_rsne_suppressions_address", unique: true
  end

  create_table "recording_studio_notifications_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "notification_type", null: false
    t.string "recipient_type", null: false
    t.uuid "recipient_id", null: false
    t.string "actor_type"
    t.uuid "actor_id"
    t.string "notifiable_type"
    t.uuid "notifiable_id"
    t.uuid "recording_id"
    t.uuid "root_recording_id"
    t.string "title", null: false
    t.text "body"
    t.string "url"
    t.jsonb "metadata", default: {}, null: false
    t.string "idempotency_key"
    t.datetime "read_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "cleared_at"
    t.boolean "inbox", default: true, null: false
    t.index ["recipient_type", "recipient_id", "idempotency_key"], name: "idx_rsn_notifications_idempotency", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["recipient_type", "recipient_id", "notification_type"], name: "idx_rsn_notifications_recipient_type"
    t.index ["recording_id"], name: "idx_rsn_notifications_recording"
    t.index ["root_recording_id", "created_at"], name: "idx_rsn_notifications_root_created"
  end

  create_table "recording_studio_notifications_preferences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "recipient_type", null: false
    t.uuid "recipient_id", null: false
    t.string "notification_type", null: false
    t.string "channel"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cadence"
    t.index ["notification_type", "channel"], name: "idx_rsn_preferences_type_channel"
    t.index ["recipient_type", "recipient_id", "notification_type", "channel"], name: "idx_rsn_preferences_channel", unique: true, where: "(channel IS NOT NULL)"
    t.index ["recipient_type", "recipient_id", "notification_type"], name: "idx_rsn_preferences_cadence", unique: true, where: "(channel IS NULL)"
    t.check_constraint "channel IS NOT NULL AND enabled IS NOT NULL AND cadence IS NULL OR channel IS NULL AND enabled IS NULL AND cadence IS NOT NULL", name: "chk_rsn_preferences_shape"
  end

  create_table "recording_studio_publishable_publishables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.datetime "publish_at"
    t.datetime "unpublish_at"
    t.string "time_zone"
    t.string "seo_title"
    t.text "seo_description"
    t.string "canonical_url"
    t.string "meta_robots"
    t.string "social_title"
    t.text "social_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "social_image_attachment_recording_id"
    t.index ["canonical_url"], name: "index_rs_publishables_on_canonical_url"
    t.index ["slug"], name: "index_rs_publishables_on_slug"
    t.index ["social_image_attachment_recording_id"], name: "index_rs_publishables_on_social_image_attachment_recording_id"
    t.index ["status", "publish_at", "unpublish_at"], name: "index_publishables_on_status_and_publish_times"
    t.index ["status", "publish_at", "unpublish_at"], name: "index_rs_publishables_on_state_window"
  end

  create_table "recording_studio_recordings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "parent_recording_id"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "root_recording_id"
    t.datetime "trashed_at"
    t.datetime "updated_at", null: false
    t.index ["parent_recording_id"], name: "index_recording_studio_recordings_on_parent_recording_id"
    t.index ["parent_recording_id"], name: "index_rs_publishable_child_per_parent", unique: true, where: "(((recordable_type)::text = 'RecordingStudioPublishable::Publishable'::text) AND (trashed_at IS NULL))"
    t.index ["recordable_type", "recordable_id", "parent_recording_id", "trashed_at"], name: "index_recording_studio_recordings_on_recordable_parent_trashed"
    t.index ["recordable_type", "recordable_id"], name: "index_recording_studio_recordings_on_recordable"
    t.index ["recordable_type", "recordable_id"], name: "index_rs_unique_root_recording_per_recordable", unique: true, where: "(parent_recording_id IS NULL)"
    t.index ["root_recording_id", "parent_recording_id"], name: "index_rs_recordings_on_root_and_parent"
    t.index ["root_recording_id", "recordable_type", "recordable_id"], name: "index_rs_recordings_on_root_and_recordable"
    t.index ["root_recording_id"], name: "index_rs_recordings_on_root_recording"
  end

  create_table "recording_studio_root_switchable_selections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "device_browser"
    t.string "device_key", null: false
    t.string "device_label"
    t.string "device_platform"
    t.string "device_type"
    t.datetime "last_used_at", null: false
    t.uuid "root_recording_id", null: false
    t.string "scope_key", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["actor_type", "actor_id", "device_key", "scope_key"], name: "idx_rs_root_switchable_actor_device_scope", unique: true, where: "(actor_id IS NOT NULL)"
    t.index ["device_key", "scope_key"], name: "idx_rs_root_switchable_anonymous_device_scope", unique: true, where: "(actor_id IS NULL)"
    t.index ["root_recording_id"], name: "idx_rs_root_switchable_root_recording"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "recording_studio_access_invitations", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_events", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_notifications_deliveries", "recording_studio_notifications_notifications", column: "notification_id"
  add_foreign_key "recording_studio_publishable_publishables", "recording_studio_recordings", column: "social_image_attachment_recording_id", name: "fk_rs_publishables_social_image_attachment_recording"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "parent_recording_id"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "root_recording_id"
end
