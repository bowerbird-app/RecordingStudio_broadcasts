# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Publishable's publish_at is the send clock. These methods set that clock
  # and turn the published event into one launch.
  module SendClock
    # sent_at is the idempotency guard. A reschedule, a late job, or a second
    # publish must not snapshot the audience again. A send already in progress
    # may re-enqueue delivery; that path claims each recipient once.
    def launch(recording, actor:, scheduled_at: nil)
      raise ArgumentError, "actor is required" if actor.nil?

      unless sender_allowed?(recording, actor)
        Rails.logger&.warn(
          "RecordingStudioBroadcasts skipped send for recording #{recording.id}: " \
          "#{actor.id} is not allowed to send"
        )
        return recording
      end

      DeliverBroadcastJob.perform_later(recording, actor) if claim_send!(recording, actor:, scheduled_at:)
      recording
    end

    def claim_send!(recording, actor:, scheduled_at:)
      recording.with_lock do
        broadcast = recording.recordable
        next false unless due?(broadcast, scheduled_at)
        next broadcast.status == "sending" if broadcast.sent_at.present?
        next false unless Campaign::EDITABLE.include?(broadcast.status)

        Audience.snapshot!(recording)
        revise!(recording, actor:, status: "sending", sent_at: Time.current)
        true
      end
    end

    def schedule(recording, at:, actor:)
      scheduled_at = at&.utc
      assert_action!(recording, :schedule)
      raise_blank_schedule!(recording) if scheduled_at.blank?
      return publish_now(recording, actor:) if scheduled_at <= Time.current

      # One transaction so a failed revise cannot leave a publishable clock or a window job behind.
      recording.transaction do
        PublishableSchedule.schedule_at(recording, at: scheduled_at, actor:)
        revise!(recording, actor:, status: "scheduled", scheduled_at:, metadata: { source: "schedule" })
      end
      recording
    end

    # Publishing with no future time sends the way Send now always has.
    # That write emits published with source "write", which deliver_published ignores,
    # so this launch is the only delivery enqueue.
    def publish_now(recording, actor:)
      assert_action!(recording, :send)
      PublishableSchedule.publish_now(recording, actor:)
      recording.reload
      launch(recording, actor:) if recording.recordable.sent_at.blank?
      recording
    end

    def unpublish(recording, actor:)
      assert_action!(recording, :unpublish)
      raise InvalidTransition, "A sent broadcast cannot be unpublished" if recording.recordable.sent_at.present?

      recording.transaction do
        PublishableSchedule.unpublish(recording, actor:)
        revise!(recording, actor:, status: "draft", scheduled_at: nil)
      end
      recording
    end

    # A Publishable publish from its own UI or API uses source "write" and must not send.
    # Only the window job (source "scheduled") sends, and only while the broadcast is still scheduled.
    def deliver_published(payload)
      return unless scheduled_window?(payload)

      recording = RecordingStudio::Recording.find_by(id: payload[:recording_id])
      return if recording.nil? || recording.recordable.status != "scheduled"
      # A Publishable edit can move publish_at off this broadcast's clock.
      # The old job then matches nothing, so the row would stay scheduled on a past time.
      # Draft it instead of overwriting that edit.
      return release_mismatched_schedule!(recording, payload) unless clock_matches?(recording, payload)

      actor = scheduling_actor(recording) || actor_from(payload)
      return log_skipped_send(recording, "no actor") if actor.nil?

      launch(recording, actor:, scheduled_at: publish_clock(payload))
    end

    # The window job's publish_at must still be this broadcast's clock.
    # A Publishable edit can queue an earlier job while status stays scheduled.
    def scheduled_window?(payload)
      payload[:source].to_s == "scheduled" &&
        payload[:recordable_type] == Broadcast.name &&
        publish_clock(payload).present?
    end

    def publish_clock(payload)
      payload.dig(:current_state, :publish_at)&.utc&.iso8601
    end

    def clock_matches?(recording, payload)
      recording.recordable.scheduled_at&.utc&.iso8601 == publish_clock(payload)
    end

    def log_skipped_send(recording, reason)
      Rails.logger&.warn("RecordingStudioBroadcasts skipped send for recording #{recording.id}: #{reason}")
    end

    def clear_publishable!(recording, actor:)
      publishable = recording.current_publishable
      return if publishable.nil? || publishable.status == "draft"

      PublishableSchedule.unpublish(recording, actor:)
    end

    # revise stores the scheduler on the schedule event. The window job emits with no actor.
    def scheduling_actor(recording)
      # Recording Studio is Postgres-only, so this JSON lookup stays as metadata ->> 'source'.
      event = RecordingStudio::Event.where(recording_id: recording.id, action: "updated")
                                    .where("metadata ->> 'source' = ?", "schedule")
                                    .order(occurred_at: :desc)
                                    .first
      event&.actor
    end

    def raise_blank_schedule!(recording)
      broadcast = recording.recordable
      broadcast.errors.add(:scheduled_at, "can't be blank")
      raise ActiveRecord::RecordInvalid, broadcast
    end

    def actor_from(payload)
      type = payload[:actor_type]
      id = payload[:actor_id]
      return if type.blank? || id.blank?

      type.constantize.find_by(id:)
    rescue NameError
      nil
    end
  end
end
