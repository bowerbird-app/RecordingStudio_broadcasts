# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Lookup
      module_function

      def create_parent(context)
        parent_id = payload_parent_id(context)
        return scoped_parent!(context, parent_id) if parent_id.present?

        context.access_grant.scope_recording
      end

      def recordings(context)
        Campaign.recordings(context.access_grant.scope_recording)
      end

      def recording!(context)
        recording = recordings(context).find_by(id: recording_id(context))
        raise RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if recording.nil?

        recording
      end

      def recording_id(context)
        return context.id if context.respond_to?(:id) && context.id.present?
        return context.recording.id if context.respond_to?(:recording) && context.recording

        context.params[:id] if context.respond_to?(:params)
      end

      def payload_parent_id(context)
        payload = RecordingStudioApi::RequestPayload.call(context)
        payload[:parent_id].presence || payload["parent_id"].presence
      end

      def scoped_parent!(context, parent_id)
        parent = context.access_grant.accessible_recordings.find_by(id: parent_id)
        raise RecordingStudioApi::NotFoundError, "Parent resource was not found in this API scope" if parent.nil?

        parent
      end

      def content_attributes(context)
        payload = RecordingStudioApi::RequestPayload.call(context)
        symbolized = payload.respond_to?(:deep_symbolize_keys) ? payload.deep_symbolize_keys : {}
        symbolized.slice(*Api.content_keys)
      end
    end
  end
end
