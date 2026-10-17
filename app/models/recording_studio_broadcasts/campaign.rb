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
    private_class_method :assert_allowed!
  end
end
