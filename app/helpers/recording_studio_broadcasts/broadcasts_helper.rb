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

    def self.schedule_state(_recording, broadcast)
      if broadcast.sent_at.present?
        { label: "Sent", style: :success, time: broadcast.sent_at }
      elsif broadcast.status == "scheduled" && broadcast.scheduled_at.present?
        # The screen shows this broadcast's clock. A drifted publish_at is not the send time.
        { label: "Scheduled", style: :info, time: broadcast.scheduled_at }
      end
    end

    def broadcast_schedule_state(recording, broadcast)
      BroadcastsHelper.schedule_state(recording, broadcast)
    end

    def broadcast_publishable_return_notice(recording)
      BroadcastsHelper.publishable_return_notice(recording)
    end

    def self.publishable_return_notice(recording)
      return unless recording.recordable.status == "draft"

      event = recording.events(actions: "updated", limit: 1).first
      return unless event&.metadata.to_h.stringify_keys["source"] == "publishable_change"

      "Returned to draft: send time changed in Publishable by #{editor_name(event.actor)}"
    end

    def self.editor_name(actor)
      return "the system" if actor.nil?
      return actor.name if actor.respond_to?(:name) && actor.name.present?
      return actor.email if actor.respond_to?(:email) && actor.email.present?

      "the system"
    end
    private_class_method :editor_name

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
