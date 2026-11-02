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
      key = "broadcast/#{row.recording_id}/#{row.recipient_type}/#{row.recipient_id}"
      notification, error = notify_result(row.recording, row.recipient, key)
      record_send!(row, notification, error)
    end

    def finished?(recording)
      Recipient.where(recording_id: recording.id, status: %w[pending sending]).none?
    end

    def test_send(recording, actor:)
      notification, error = notify_result(
        recording, actor, "broadcast/#{recording.id}/test/#{actor.class.name}/#{actor.id}"
      )
      raise error if error && !known_send_error?(error)

      notification
    end

    def email_failed?(notification)
      delivery = notification.deliveries.find_by(channel: "email")
      delivery.present? && !delivery.delivered?
    end

    def claim_batch(recording_id)
      ids = Recipient.where(recording_id:).claimable.order(:id).lock("FOR UPDATE SKIP LOCKED")
                     .limit(RecordingStudioBroadcasts.configuration.batch_size).pluck(:id)
      now = Time.current
      Recipient.where(id: ids).update_all(status: "sending", claimed_at: now, updated_at: now)
      Recipient.where(id: ids).order(:id).includes(:recipient, recording: :recordable).to_a
    end

    def record_send!(row, notification, error)
      raise error unless error.nil? || known_send_error?(error)

      report_adapter_error(row, error)
      row.update!(notification_id: notification&.id, **attrs_for(notification, error))
    end

    def report_adapter_error(row, error)
      return unless error.is_a?(RecordingStudioNotificationsEmail::DeliveryError)

      Rails.error.report(error, handled: true, context: { broadcast_recipient_id: row.id })
    end

    def attrs_for(notification, error)
      case error
      when RecordingStudioNotificationsEmail::SuppressedRecipientError
        { status: "skipped", skip_reason: "suppressed" }
      when RecordingStudioNotificationsEmail::DeliveryError
        { status: "failed" }
      else
        outcome(notification)
      end
    end

    def notify_result(recording, recipient, idempotency_key)
      broadcast = recording.recordable
      with_adapter_error do
        RecordingStudioNotifications.notify(
          notification_type: NOTIFICATION_TYPE, recipient:, idempotency_key:,
          title: broadcast.subject, body: broadcast.body,
          channels: [:email], inbox: false, deliver_later: false
        )
      end
    end

    # Notifications' delivery job records adapter errors and swallows them unless
    # raise_on_delivery_error is set. subscribed is only active for this block.
    def with_adapter_error(&)
      error = nil
      notification = ActiveSupport::Notifications.subscribed(
        lambda do |_name, _started, _finished, _id, payload|
          error ||= payload[:exception_object]
        end,
        "deliver.recording_studio_notifications",
        &
      )
      [notification, error]
    end

    def outcome(notification)
      return { status: "skipped", skip_reason: "preference" } if notification.nil?

      delivery = notification.deliveries.find_by(channel: "email")
      return { status: "sent" } if delivery&.delivered?

      { status: "failed" }
    end

    def known_send_error?(error)
      error.is_a?(RecordingStudioNotificationsEmail::SuppressedRecipientError) ||
        error.is_a?(RecordingStudioNotificationsEmail::DeliveryError)
    end

    private_class_method :claim_batch, :record_send!, :report_adapter_error, :attrs_for, :notify_result,
                         :with_adapter_error, :outcome, :known_send_error?
  end
end
