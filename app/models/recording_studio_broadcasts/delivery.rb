# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Delivery
    SUPPRESSED_MESSAGE = "email recipient is suppressed"

    module_function

    def claim(recording)
      Recipient.transaction do
        current = RecordingStudio::Recording.unscoped.lock("FOR SHARE").find(recording.id)
        current.recordable.status == "sending" ? claim_batch(recording.id) : []
      end
    end

    def deliver_one(row)
      row.update!(attempt(row))
    rescue RecordingStudioNotificationsEmail::SuppressedRecipientError
      row.update!(status: "skipped", skip_reason: "suppressed")
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { broadcast_recipient_id: row.id })
      row.update!(status: "failed")
    end

    def finished?(recording)
      Recipient.where(recording_id: recording.id, status: %w[pending sending]).none?
    end

    def test_send(recording, actor:)
      notify(recording, actor, "broadcast/#{recording.id}/test/#{actor.class.name}/#{actor.id}")
    end

    def claim_batch(recording_id)
      ids = Recipient.where(recording_id:).claimable.order(:id).lock("FOR UPDATE SKIP LOCKED")
                     .limit(RecordingStudioBroadcasts.configuration.batch_size).pluck(:id)
      now = Time.current
      Recipient.where(id: ids).update_all(status: "sending", claimed_at: now, updated_at: now)
      Recipient.where(id: ids).order(:id).includes(:recipient, recording: :recordable).to_a
    end

    def attempt(row)
      return { status: "skipped", skip_reason: "preference" } unless preference_enabled?(row.recipient)

      key = "broadcast/#{row.recording_id}/#{row.recipient_type}/#{row.recipient_id}"
      notification = notify(row.recording, row.recipient, key)
      { notification_id: notification&.id, **outcome(notification) }
    end

    def notify(recording, recipient, idempotency_key)
      broadcast = recording.recordable
      RecordingStudioNotifications.notify(
        notification_type: NOTIFICATION_TYPE, recipient:, idempotency_key:,
        title: broadcast.subject, body: broadcast.body,
        channels: [:email], inbox: false, deliver_later: false
      )
    end

    def outcome(notification)
      return { status: "skipped", skip_reason: "preference" } if notification.nil?

      delivery = notification.deliveries.find_by(channel: "email")
      return { status: "sent" } if delivery&.delivered?
      return { status: "skipped", skip_reason: "suppressed" } if delivery&.error_message == SUPPRESSED_MESSAGE

      { status: "failed" }
    end

    def preference_enabled?(recipient)
      RecordingStudioNotifications::Preference.enabled_for?(
        recipient:, notification_type: NOTIFICATION_TYPE, channel: :email, default: true
      )
    end

    private_class_method :claim_batch, :attempt, :notify, :outcome, :preference_enabled?
  end
end
