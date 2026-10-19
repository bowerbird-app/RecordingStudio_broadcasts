# frozen_string_literal: true

module RecordingStudioBroadcasts
  module BroadcastsHelper
    STATUS_STYLES = {
      "draft" => :default,
      "scheduled" => :info,
      "sending" => :warning,
      "completed" => :success,
      "cancelled" => :default
    }.freeze

    def self.schedule_text(recording)
      broadcast = recording.recordable
      state = schedule_state(recording, broadcast)
      return "Not scheduled" if state.nil?

      "#{state[:label]} · #{I18n.l(state[:time].in_time_zone, format: :long)}"
    end

    PUBLISHABLE_TYPE = "RecordingStudioPublishable::Publishable"

    def self.schedule_state(recording, broadcast)
      if broadcast.sent_at.present?
        { label: "Sent", style: :success, time: broadcast.sent_at }
      elsif broadcast.status == "scheduled"
        time = publish_at_for(recording) || broadcast.scheduled_at
        { label: "Scheduled", style: :info, time: time } if time.present?
      end
    end

    # Prefer the preloaded publishable child so a table of broadcasts does not query per row.
    def self.publish_at_for(recording)
      publishable_for(recording)&.publish_at
    end

    def self.publishable_for(recording)
      child = publishable_child(recording)
      return if child.nil?

      child.recordable
    end

    def self.publishable_child(recording)
      children = recording.child_recordings
      if children.loaded?
        children.find { |row| row.recordable_type == PUBLISHABLE_TYPE && row.trashed_at.nil? }
      else
        recording.publishable_child_recording
      end
    end

    def broadcast_schedule_state(recording, broadcast)
      BroadcastsHelper.schedule_state(recording, broadcast)
    end

    def broadcast_action_button(text, url, confirm: nil)
      data = { turbo_method: :post }
      data[:turbo_confirm] = confirm if confirm.present?
      FlatPack::Button::Component.new(text: text, href: url, data: data)
    end

    def broadcast_status_badge(broadcast)
      FlatPack::Badge::Component.new(
        text: Campaign::STATUS_LABELS.fetch(broadcast.status),
        style: STATUS_STYLES.fetch(broadcast.status)
      )
    end

    def broadcast_filter_summary(broadcast)
      values = broadcast.filter_params.to_h
      chosen = RecordingStudioBroadcasts.filters.all.filter_map do |filter|
        value = values[filter.key]
        "#{filter.label}: #{value}" if value.present?
      end
      chosen.any? ? chosen.join(" and ") : "Everyone"
    end

    def broadcast_filter_input(filter, value)
      name = "broadcast[filter_params][#{filter.key}]"
      case filter.input
      when :date then FlatPack::DateInput::Component.new(name:, label: filter.label, value:)
      when :select
        FlatPack::Select::Component.new(name:, label: filter.label, value:, options: [["Anyone", ""], *filter.options])
      else FlatPack::TextInput::Component.new(name:, label: filter.label, value:)
      end
    end

    def broadcast_field_error(broadcast, attribute)
      broadcast.errors[attribute].to_sentence.presence
    end
  end
end
