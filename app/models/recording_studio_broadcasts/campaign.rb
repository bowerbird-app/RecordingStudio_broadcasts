# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Campaign
    TRANSITIONS = {
      "draft" => %w[scheduled sending cancelled],
      "scheduled" => %w[draft sending cancelled],
      "sending" => %w[completed cancelled],
      "completed" => [],
      "cancelled" => []
    }.freeze
    EDITABLE = %w[draft scheduled].freeze
    CONTENT = %i[title subject body filter_params].freeze

    module_function

    def create(parent_recording, actor:, **attributes)
      parent_recording.record(Broadcast, actor:) { |broadcast| broadcast.assign_attributes(attributes.slice(*CONTENT)) }
    end

    def update(recording, actor:, **attributes)
      revise!(recording, actor:, **attributes.slice(*CONTENT))
    end

    def launch(recording, actor:, scheduled_at: nil)
      launched = recording.with_lock do
        broadcast = recording.recordable
        next false unless due?(broadcast, scheduled_at)
        next broadcast.status == "sending" unless EDITABLE.include?(broadcast.status)

        Audience.snapshot!(recording)
        revise!(recording, actor:, status: "sending")
        true
      end
      DeliverBroadcastJob.perform_later(recording, actor) if launched
      recording
    end

    def schedule(recording, at:, actor:)
      scheduled_at = at.utc
      revise!(recording, actor:, status: "scheduled", scheduled_at:)
      ScheduledBroadcastJob.set(wait_until: scheduled_at).perform_later(recording, scheduled_at.iso8601, actor)
      recording
    end

    def cancel(recording, actor:)
      recording.with_lock do
        revise!(recording, actor:, status: "cancelled")
        Recipient.where(recording_id: recording.id, status: "pending")
                 .update_all(status: "skipped", skip_reason: "cancelled", updated_at: Time.current)
      end
      recording
    end

    def complete!(recording, actor:)
      recording.with_lock do
        revise!(recording, actor:, status: "completed") if recording.recordable.status == "sending"
      end
    end

    def revise!(recording, actor:, status: nil, **changes)
      recording.with_lock do
        from = recording.recordable.status
        to = (status || from).to_s
        assert_allowed!(from, to, editing: changes.any?)

        recording.parent_recording.revise(recording, actor:) do |broadcast|
          broadcast.assign_attributes(changes.merge(status: to))
        end
      end
    end

    def assert_allowed!(from, to, editing:)
      raise InvalidTransition, "A #{from} broadcast cannot be edited" if editing && !EDITABLE.include?(from)
      return if to == from || TRANSITIONS.fetch(from).include?(to)

      raise InvalidTransition, "A #{from} broadcast cannot become #{to}"
    end

    # A reschedule leaves the earlier job queued, so a job may launch only while its clock is still the schedule.
    def due?(broadcast, scheduled_at)
      scheduled_at.nil? || (broadcast.status == "scheduled" && broadcast.scheduled_at.utc.iso8601 == scheduled_at)
    end
    private_class_method :assert_allowed!, :due?
  end
end
