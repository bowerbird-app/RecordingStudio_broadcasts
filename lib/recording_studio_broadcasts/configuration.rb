# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Configuration
    Recipients = Data.define(:relation)

    attr_accessor :admin_root_type

    def initialize
      @admin_root_type = "AdminRoot"
    end

    def recipients(relation: nil)
      return @recipients = Recipients.new(relation:) if relation

      @recipients || raise(Error, "Call config.recipients(relation: -> { ... }) in your initializer")
    end
  end
end
