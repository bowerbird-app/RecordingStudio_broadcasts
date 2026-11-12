# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Resources
      class Index < RecordingStudioApi::Services::ResourceOperations::Index
        def filtered_recordings
          Campaign.recordings(access_scope_recording)
        end
      end

      class Show
        def self.call(context)
          recording = Lookup.recording!(context)
          context.access_grant.authorize!(recording: recording, role: :view)
          { json: Serialize.recording(recording, context) }
        end
      end

      class Create
        def self.call(context)
          parent = Lookup.create_parent(context)
          context.access_grant.authorize!(recording: parent, role: :admin)
          recording = Errors.with_domain_errors do
            Campaign.create(parent, actor: context.actor, **Lookup.content_attributes(context))
          end
          { json: Serialize.recording(recording, context), status: :created }
        end
      end

      class Update
        def self.call(context)
          recording = Lookup.recording!(context)
          context.access_grant.authorize!(recording: recording, role: :admin)
          updated = Errors.with_domain_errors do
            Campaign.update(recording, actor: context.actor, **Lookup.content_attributes(context))
          end
          { json: Serialize.recording(updated, context) }
        end
      end

      class Destroy
        def self.call(context)
          recording = Lookup.recording!(context)
          context.access_grant.authorize!(recording: recording, role: :admin)
          serialized = Serialize.recording(recording, context)
          Errors.with_domain_errors { Campaign.destroy(recording, actor: context.actor) }
          { json: serialized.merge(deleted: true, deleted_via: "destroyed") }
        end
      end
    end
  end
end
