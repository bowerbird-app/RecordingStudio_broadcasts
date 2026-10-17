# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Audience
    module_function

    def matching_scope(filter_params)
      RecordingStudioBroadcasts.filters.apply(recipients.relation.call, filter_params)
    end

    def counts(filter_params)
      matching = 0
      eligible = 0
      matching_scope(filter_params).find_each do |recipient|
        matching += 1
        eligible += 1 if eligible?(recipient)
      end
      { matching:, eligible:, excluded: matching - eligible }
    end

    def snapshot!(recording)
      matching_scope(recording.recordable.filter_params).find_in_batches do |batch|
        rows = batch.select { |recipient| eligible?(recipient) }.map { |recipient| row_for(recording, recipient) }
        Recipient.insert_all(rows, unique_by: %i[recording_id recipient_type recipient_id]) if rows.any?
      end
    end

    def eligible?(recipient)
      email = recipients.email_for(recipient)
      return false if email.blank?
      return false unless RecordingStudioNotifications::Preference.enabled_for?(
        recipient:, notification_type: NOTIFICATION_TYPE, channel: :email, default: true
      )

      !undeliverable?(email)
    end

    def undeliverable?(email)
      RecordingStudioNotificationsEmail::Suppression.suppressed?(email)
    rescue ArgumentError
      true
    end

    def row_for(recording, recipient)
      now = Time.current
      {
        recording_id: recording.id,
        root_recording_id: recording.root_recording_id,
        recipient_type: recipient.class.polymorphic_name,
        recipient_id: recipient.id,
        status: "pending",
        created_at: now,
        updated_at: now
      }
    end

    def recipients
      RecordingStudioBroadcasts.configuration.recipients
    end

    private_class_method :undeliverable?, :row_for, :recipients
  end
end
