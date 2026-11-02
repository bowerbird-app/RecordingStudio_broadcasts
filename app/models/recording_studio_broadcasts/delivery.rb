# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Delivery
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
    rescue RecordingStudioNotificationsEmail::DeliveryError => e
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
      key = "broadcast/#{row.recording_id}/#{row.recipient_type}/#{row.recipient_id}"
      notification = notify(row.recording, row.recipient, key)
      { notification_id: notification&.id, **outcome(notification) }
    end

    def notify(recording, recipient, idempotency_key)
      broadcast = recording.recordable
      capturing_delivery_error do
        RecordingStudioNotifications.notify(
          notification_type: NOTIFICATION_TYPE, recipient:, idempotency_key:,
          title: broadcast.subject, body: broadcast.body,
          channels: [:email], inbox: false, deliver_later: false
        )
      end
    end

    # Notifications' delivery job records adapter errors on the delivery row and
    # swallows them unless raise_on_delivery_error is set. Re-raise so this gem
    # can skip suppressions and fail only known send errors.
    def capturing_delivery_error(&)
      error = nil
      notification = ActiveSupport::Notifications.subscribed(
        lambda do |_name, _started, _finished, _id, payload|
          error ||= payload[:exception_object]
        end,
        "deliver.recording_studio_notifications",
        &
      )
      raise error if error

      notification
    end

    def outcome(notification)
      return { status: "skipped", skip_reason: "preference" } if notification.nil?

      delivery = notification.deliveries.find_by(channel: "email")
      return { status: "sent" } if delivery&.delivered?

      { status: "failed" }
    end

    private_class_method :claim_batch, :attempt, :notify, :capturing_delivery_error, :outcome
  end
end
