# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Configuration
    Recipients = Data.define(:relation)

    attr_accessor :batch_size, :admin_root_type

    def initialize
      @batch_size = 100
      @admin_root_type = "AdminRoot"
    end

    def recipients(relation: nil)
      return @recipients = Recipients.new(relation:) if relation

      @recipients || raise(Error, "Call config.recipients(relation: -> { ... }) in your initializer")
    end
  end
end
