# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module CampaignRecording
      module_function

      def parent_for(context)
        parent_id = raw_parent_id(context)
        return find_scoped(context, parent_id) if parent_id.present?

        context.access_grant&.scope_recording || context.root_recording
      end

      def parent!(context, role:)
        parent = parent_for(context)
        raise RecordingStudioApi::NotFoundError, "Broadcast parent was not found" if parent.blank?

        context.access_grant.authorize!(recording: parent, role: role)
        parent
      end

      def recordings(context)
        parent = parent_for(context)
        raise RecordingStudioApi::NotFoundError, "Broadcast parent was not found" if parent.blank?

        RecordingStudioBroadcasts::Campaign.recordings(parent)
      end

      def find!(context)
        recording = context.recording if context.respond_to?(:recording)
        recording ||= recordings(context).find_by(id: recording_id(context))
        raise RecordingStudioApi::NotFoundError, "Broadcast was not found" if recording.blank?
        raise RecordingStudioApi::NotFoundError, "Broadcast was not found" unless campaign_recording?(recording)

        recording
      end

      def campaign_recording?(recording)
        recording.recordable_type == RECORDABLE_TYPE
      end

      def recording_id(context)
        return context.id if context.respond_to?(:id) && context.id.present?
        return context.recording.id if context.respond_to?(:recording) && context.recording

        params = context.params
        params[:id] || params["id"] if params.respond_to?(:[])
      end

      def raw_parent_id(context)
        return context.parent_id if context.respond_to?(:parent_id) && context.parent_id.present?

        payload = Attributes.payload(context)
        payload[:parent_id] || payload["parent_id"]
      end

      def find_scoped(context, id)
        if context.respond_to?(:scoped_recordings) && context.scoped_recordings
          found = context.scoped_recordings.find_by(id: id)
          return found if found
        end

        RecordingStudio::Recording.find_by(id: id)
      end
    end
  end
end
