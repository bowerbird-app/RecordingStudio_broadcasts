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
    STATUS_LABELS = {
      "draft" => "Draft",
      "scheduled" => "Scheduled",
      "sending" => "Sending",
      "completed" => "Sent",
      "cancelled" => "Cancelled"
    }.freeze

    extend SendClock
    extend PublishableWithdrawal

    module_function

    def recordings(parent_recording)
      parent_recording.recordings_query(type: Broadcast)
    end

    def actions_for(status)
      editable = EDITABLE.include?(status)
      {
        update: editable,
        schedule: editable,
        test_send: editable,
        send: TRANSITIONS.fetch(status).include?("sending"),
        unpublish: status == "scheduled",
        cancel: TRANSITIONS.fetch(status).include?("cancelled"),
        delete: status == "draft"
      }.select { |_action, offered| offered }.keys
    end

    def create(parent_recording, actor:, **attributes)
      parent_recording.record(Broadcast, actor:) { |broadcast| broadcast.assign_attributes(attributes.slice(*CONTENT)) }
    end

    def destroy(recording, actor:)
      recording.with_lock do
        status = recording.recordable.status
        raise InvalidTransition, "A #{status} broadcast cannot be deleted" unless actions_for(status).include?(:delete)

        snapshot_ids = recording.recordables.map(&:id)
        parent = recording.parent_recording
        parent.log_event(parent, action: "deleted", actor:, metadata: { broadcast_recording_id: recording.id })
        recording.destroy!
        Broadcast.where(id: snapshot_ids).delete_all
      end
    end

    def update(recording, actor:, **attributes)
      revise!(recording, actor:, **attributes.slice(*CONTENT))
    end

    def cancel(recording, actor:)
      recording.with_lock do
        clear_publishable!(recording, actor:)
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

    def revise!(recording, actor:, status: nil, metadata: {}, **changes)
      recording.with_lock do
        from = recording.recordable.status
        to = (status || from).to_s
        assert_allowed!(from, to, editing: changes.any?)

        recording.parent_recording.revise(recording, actor:, metadata:) do |broadcast|
          broadcast.assign_attributes(changes.merge(status: to))
        end
      end
    end

    def assert_action!(recording, action)
      # revise replaces the recordable, so a caller holding the recording still
      # has the previous snapshot cached until this reload.
      status = recording.reload.recordable.status
      return if actions_for(status).include?(action)

      raise InvalidTransition, "A #{status} broadcast cannot be #{action.to_s.tr('_', ' ')}"
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
    private_class_method :claim_send!, :assert_action!, :assert_allowed!, :due?,
                         :raise_blank_schedule!, :actor_from, :clear_publishable!, :scheduling_actor,
                         :sender_allowed?, :scheduled_window?, :publish_clock
  end
end
