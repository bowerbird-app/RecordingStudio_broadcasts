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
