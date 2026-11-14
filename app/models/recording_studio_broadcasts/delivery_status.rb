# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Fan-out does not write broadcast recipient rows. This records the snapshot
  # status the admin detail page counts, from each inserted notification and
  # from the email delivery that follows.
  module DeliveryStatus
    SUPPRESSED_MESSAGE = "email recipient is suppressed"
    TERMINAL = %w[sent skipped failed].freeze

    module_function

    def record_chunk(recording, people)
      return if people.empty?

      rows = rows_for(recording, people)
      notes = notifications_for(recording, people)
      people.each { |person| record_person(rows[person.id.to_s], notes[person.id.to_s]) }
    end

    def record_delivery(event)
      return unless event.payload[:channel].to_s == "email"

      notification = notification_for(event)
      row = row_for(notification)
      return if row.nil?

      apply_event!(row, notification, event.payload[:exception_object])
      finish_later(row)
    end

    def record_person(row, notification)
      return if row.nil? || terminal?(row)
      return apply_outcome!(row, notification) if notification
      return unless row.status == "pending"

      row.update!(status: "skipped", skip_reason: "preference")
    end

    def rows_for(recording, people)
      Recipient.where(recording_id: recording.id, recipient_id: people.map(&:id))
               .index_by { |row| row.recipient_id.to_s }
    end

    def notifications_for(recording, people)
      RecordingStudioNotifications::Notification
        .where(notification_scope(recording, people))
        .includes(:deliveries)
        .index_by { |notification| notification.recipient_id.to_s }
    end

    def notification_scope(recording, people)
      {
        idempotency_key: Delivery.idempotency_key(recording),
        recipient_type: people.first.class.base_class.name,
        recipient_id: people.map(&:id)
      }
    end

    def notification_for(event)
      found = RecordingStudioNotifications::Notification.find_by(id: event.payload[:notification_id])
      found if found && broadcast_id(found)
    end

    def row_for(notification)
      return if notification.nil?

      Recipient.find_by(recording_id: broadcast_id(notification), recipient_id: notification.recipient_id)
    end

    def broadcast_id(notification)
      notification.idempotency_key.to_s[%r{\Abroadcast/([0-9a-f-]{36})\z}i, 1]
    end

    def finish_later(row)
      return if Delivery.fan_out_active?

      recording = RecordingStudio::Recording.find_by(id: row.recording_id)
      Delivery.finish(recording, nil) if recording
    end

    def apply_outcome!(row, notification)
      return if terminal?(row)

      email = notification.deliveries.find { |delivery| delivery.channel == "email" }
      row.update!(outcome_for(email).merge(notification_id: notification.id))
    end

    def apply_event!(row, notification, error)
      return if terminal?(row)

      row.update!(event_outcome(error).merge(notification_id: notification.id))
    end

    def outcome_for(email)
      return in_flight if email.nil? || email.pending? || email.processing?
      return sent if email.delivered?
      return suppressed if email.error_message == SUPPRESSED_MESSAGE

      failed
    end

    def event_outcome(error)
      return sent if error.nil?
      return suppressed if suppressed_error?(error)

      failed
    end

    def terminal?(row)
      row.skip_reason == "cancelled" || TERMINAL.include?(row.status)
    end

    def suppressed_error?(error)
      error.is_a?(RecordingStudioNotificationsEmail::SuppressedRecipientError) ||
        error.message == SUPPRESSED_MESSAGE
    end

    def in_flight
      { status: "sending", claimed_at: Time.current, skip_reason: nil }
    end

    def sent
      { status: "sent", skip_reason: nil }
    end

    def failed
      { status: "failed", skip_reason: nil }
    end

    def suppressed
      { status: "skipped", skip_reason: "suppressed" }
    end
    private_class_method :record_person, :rows_for, :notifications_for, :notification_scope,
                         :notification_for, :row_for, :broadcast_id, :finish_later,
                         :apply_outcome!, :apply_event!, :outcome_for, :event_outcome,
                         :terminal?, :suppressed_error?, :in_flight, :sent, :failed, :suppressed
  end
end
