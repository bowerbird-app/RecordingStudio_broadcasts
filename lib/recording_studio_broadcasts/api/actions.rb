# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Api
    module Actions
      class Member
        def self.call(context)
          new(context).call
        end

        def initialize(context)
          @context = context
        end

        def call
          recording = Lookup.recording!(context)
          context.access_grant.authorize!(recording: recording, role: self.class::ROLE)
          result = Errors.with_domain_errors { perform(recording) }
          { json: json_for(recording, result) }
        end

        private

        attr_reader :context

        def json_for(recording, _result)
          Serialize.recording(recording.reload, context)
        end
      end

      class Preview < Member
        ROLE = :view

        def perform(recording)
          RecordingStudioBroadcasts.preview(recording)
        end

        def json_for(_recording, result)
          result
        end
      end

      class Send < Member
        ROLE = :admin

        def perform(recording)
          RecordingStudioBroadcasts.publish_now(recording, actor: context.actor)
        end
      end

      class Schedule < Member
        ROLE = :admin

        def perform(recording)
          RecordingStudioBroadcasts.schedule(recording, at: scheduled_at, actor: context.actor)
        end

        def scheduled_at
          Time.zone.parse(context.params[:scheduled_at].to_s)
        end
      end

      class Unpublish < Member
        ROLE = :admin

        def perform(recording)
          RecordingStudioBroadcasts.unpublish(recording, actor: context.actor)
        end
      end

      class Cancel < Member
        ROLE = :admin

        def perform(recording)
          RecordingStudioBroadcasts.cancel(recording, actor: context.actor)
        end
      end

      class TestSend < Member
        ROLE = :admin

        def perform(recording)
          RecordingStudioBroadcasts.test_send(recording, actor: context.actor)
        end
      end
    end
  end
end
