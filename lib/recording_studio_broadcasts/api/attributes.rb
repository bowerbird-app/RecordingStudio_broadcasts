# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Attributes
      module_function

      def content(context)
        normalized = payload(context)
        symbolized = normalized.respond_to?(:deep_symbolize_keys) ? normalized.deep_symbolize_keys : {}
        symbolized.slice(*WRITABLE_ATTRIBUTES)
      end

      def scheduled_at(context)
        value = payload(context)[:scheduled_at] || payload(context)["scheduled_at"]
        Time.zone.parse(value.to_s) if value.present?
      end

      def payload(context)
        raw = if context.respond_to?(:request_params)
                RecordingStudioApi::RequestPayload.call(context)
              else
                context.params || {}
              end
        hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        hash.respond_to?(:to_h) ? hash.to_h : {}
      end
    end
  end
end
