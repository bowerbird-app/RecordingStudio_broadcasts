# frozen_string_literal: true

module RecordingStudioBroadcasts
  class Configuration
    Recipients = Data.define(:relation, :email, :name) do
      def email_for(recipient)
        email.respond_to?(:call) ? email.call(recipient) : recipient.public_send(email)
      end
    end

    attr_accessor :batch_size, :admin_root_type

    def initialize
      @batch_size = 100
      @admin_root_type = "AdminRoot"
    end

    def recipients(relation: nil, email: :email, name: nil)
      return @recipients = Recipients.new(relation:, email:, name:) if relation

      @recipients || raise(Error, "Call config.recipients(relation: -> { ... }) in your initializer")
    end
  end
end
