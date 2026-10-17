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
      values = (params || {}).to_h.stringify_keys
      all.reduce(scope) do |narrowed, filter|
        value = values[filter.key]
        value.blank? ? narrowed : filter.apply.call(narrowed, value)
      end
    end
  end
end
