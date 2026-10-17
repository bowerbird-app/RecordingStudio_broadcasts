# frozen_string_literal: true

module RecordingStudioBroadcasts
  class FilterRegistry
    Filter = Data.define(:key, :label, :input, :options, :apply)

    def initialize
      @filters = {}
      @mutex = Mutex.new
    end

    def register(key, label:, input: :text, options: [], &apply)
      raise ArgumentError, "register_filter(#{key.inspect}) needs a block" unless apply

      filter = Filter.new(key: key.to_s, label: label.to_s, input: input.to_sym, options: options, apply: apply)
      @mutex.synchronize { @filters[filter.key] = filter }
    end

    def all
      @mutex.synchronize { @filters.values }
    end

    def apply(scope, params)
      values = present_values(params)
      all.reduce(scope) do |narrowed, filter|
        values.key?(filter.key) ? filter.apply.call(narrowed, values[filter.key]) : narrowed
      end
    end

    def unknown_keys(params)
      present_values(params).keys - all.map(&:key)
    end

    private

    def present_values(params)
      (params || {}).to_h.stringify_keys.reject { |_key, value| value.blank? }
    end
  end
end
