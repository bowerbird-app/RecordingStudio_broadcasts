# frozen_string_literal: true

require_relative "errors"
require_relative "lookup"
require_relative "serialize"
require_relative "resources"
require_relative "actions"

module RecordingStudioBroadcasts
  module Api
    module Registration
      HANDLERS = {
        index: Resources::Index,
        show: Resources::Show,
        create: Resources::Create,
        update: Resources::Update,
        destroy: Resources::Destroy,
        send: Actions::Send,
        schedule: Actions::Schedule,
        unpublish: Actions::Unpublish,
        cancel: Actions::Cancel,
        test_send: Actions::TestSend,
        preview: Actions::Preview
      }.freeze

      TYPE_OPTIONS = {
        api: OPERATIONS_API,
        operations: CRUD_ACTIONS,
        capability_actions: CAPABILITY_ACTIONS,
        auto_capability_actions: false,
        openapi: {
          tags: ["Broadcasts"],
          summary: "Admin product updates",
          description: "The same broadcasts Admin writes. Only the operations API. Not the public API."
        }
      }.freeze

      ACTION_SPECS = {
        preview: { http_verb: :get, required_role: :view, summary: "Count who would get this broadcast" },
        send: { http_verb: :post, required_role: :admin, summary: "Send this broadcast now" },
        schedule: {
          http_verb: :post,
          required_role: :admin,
          summary: "Pick a time to send this broadcast",
          input_contract: {
            reject_unknown: true,
            fields: {
              scheduled_at: { type: :string, required: true, allow_blank: false, description: "When to send it" }
            }
          }
        },
        cancel: { http_verb: :post, required_role: :admin, summary: "Cancel this broadcast" },
        test_send: { http_verb: :post, required_role: :admin, summary: "Send a test of this broadcast to you" }
      }.freeze

      module_function

      def register!
        register_type!
        register_own_actions!
        register_handlers!
      end

      def register_type!
        RecordingStudioApi.register_recordable_type_api(RECORDABLE_TYPE, **type_options)
      end

      def type_options
        TYPE_OPTIONS.merge(
          serializer: method(:serialize_broadcast),
          output_keys: Api.output_keys,
          writable_attributes: Api.content_keys
        )
      end

      def serialize_broadcast(broadcast, **)
        Serialize.attributes(broadcast)
      end

      def register_own_actions!
        ACTION_SPECS.each { |name, spec| register_own_action!(name, spec) }
      end

      def register_own_action!(name, spec)
        return if RecordingStudioApi.capability_action(name, api: OPERATIONS_API)

        RecordingStudioApi.register_capability_action(name, **action_options(name, spec))
      end

      def action_options(name, spec)
        {
          api: OPERATIONS_API,
          capability: CAPABILITY,
          version: "1.0.0",
          http_verb: spec.fetch(:http_verb),
          required_role: spec.fetch(:required_role),
          handler: HANDLERS.fetch(name),
          input_contract: spec[:input_contract],
          openapi: { summary: spec.fetch(:summary), tags: ["Broadcasts"] }
        }
      end

      def register_handlers!
        HANDLERS.each do |action, handler|
          next if RecordingStudioApi.resource_handler(RECORDABLE_TYPE, action, api: OPERATIONS_API)

          RecordingStudioApi.register_resource_handler(
            RECORDABLE_TYPE, action, api: OPERATIONS_API, handler: handler
          )
        end
      end
    end
  end
end
