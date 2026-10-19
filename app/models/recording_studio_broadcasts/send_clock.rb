# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Publishable's publish_at is the send clock. These methods set that clock
  # and turn the published event into one launch.
  module SendClock
    # sent_at is the idempotency guard. A reschedule, a late job, or a second
    # publish must not snapshot the audience again. A send already in progress
    # may re-enqueue delivery; that path claims each recipient once.
    def launch(recording, actor:, scheduled_at: nil)
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

      PublishableSchedule.schedule_at(recording, at: scheduled_at, actor:)
      revise!(recording, actor:, status: "scheduled", scheduled_at:)
      recording
    end

    # Publishing with no future time sends the way Send now always has.
    # Publishable emits published after commit, and that subscriber calls launch.
    # If the event already sent it, launch's sent_at guard does not send again.
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

      PublishableSchedule.unpublish(recording, actor:)
      revise!(recording, actor:, status: "draft", scheduled_at: nil)
      recording
    end

    def deliver_published(payload)
      return unless payload[:recordable_type] == Broadcast.name

      recording = RecordingStudio::Recording.find_by(id: payload[:recording_id])
      return if recording.nil?

      launch(recording, actor: actor_from(payload))
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
