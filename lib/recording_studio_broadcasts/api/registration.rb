# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Registration
      MEMBER_ACTIONS = {
        send: {
          capability: :publishable,
          version: "1.0.0",
          required_role: :admin,
          handler: Send
        },
        schedule: {
          capability: :publishable,
          version: "1.0.0",
          required_role: :admin,
          handler: Schedule
        },
        cancel: {
          capability: :publishable,
          version: "1.0.0",
          required_role: :admin,
          handler: Cancel
        },
        test_send: {
          capability: :publishable,
          version: "1.0.0",
          required_role: :admin,
          handler: TestSend
        },
        preview: {
          capability: :publishable,
          version: "1.0.0",
          required_role: :view,
          handler: Preview,
          serializer: Serialize::PREVIEW
        }
      }.freeze

      RESOURCE_HANDLERS = {
        index: Index,
        show: Show,
        create: Create,
        update: Update,
        destroy: Destroy,
        unpublish: Unpublish
      }.freeze

      module_function

      def register!
        close_public_api!
        register_operations_type!
        register_resource_handlers!
        register_member_actions!
      end

      def close_public_api!
        RecordingStudioApi.register_recordable_type_api(
          RECORDABLE_TYPE,
          auto_capability_actions: false,
          capability_actions: []
        )

        %i[index show create update destroy].each do |action|
          next if RecordingStudioApi.resource_handler(RECORDABLE_TYPE, action)

          RecordingStudioApi.register_resource_handler(RECORDABLE_TYPE, action, handler: Closed)
        end
      end

      def register_operations_type!
        RecordingStudioApi.register_recordable_type_api(
          RECORDABLE_TYPE,
          api: OPERATIONS_API,
          operations: %i[index show create update destroy],
          serializer: Serialize::BROADCAST,
          output_keys: %i[title subject body status scheduled_at sent_at filter_params],
          writable_attributes: WRITABLE_ATTRIBUTES,
          auto_capability_actions: false,
          capability_actions: %i[send schedule unpublish cancel test_send preview]
        )
      end

      def register_resource_handlers!
        RESOURCE_HANDLERS.each do |action, handler|
          next if RecordingStudioApi.resource_handler(RECORDABLE_TYPE, action, api: OPERATIONS_API)

          RecordingStudioApi.register_resource_handler(
            RECORDABLE_TYPE,
            action,
            api: OPERATIONS_API,
            handler: handler
          )
        end
      end

      def register_member_actions!
        MEMBER_ACTIONS.each do |name, options|
          next if RecordingStudioApi.capability_action(name, api: OPERATIONS_API)

          RecordingStudioApi.register_capability_action(name, api: OPERATIONS_API, **options)
        end
      end
    end
  end
end
