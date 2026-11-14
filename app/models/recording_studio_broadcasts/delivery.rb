# frozen_string_literal: true

module RecordingStudioBroadcasts
  module Delivery
    SCOPE = "recording_studio_broadcasts.snapshot"
    FAN_OUT = :recording_studio_broadcasts_fan_out

    module_function

    def install!
      return if @installed

      @installed = true
      register_scope
      subscribe_deliveries
    end

    def idempotency_key(recording)
      "broadcast/#{recording.id}"
    end

    def test_send(recording, actor:)
      notify(recording, actor, "broadcast/#{recording.id}/test/#{actor.class.name}/#{actor.id}")
    end

    def finished?(recording)
      Recipient.where(recording_id: recording.id, status: %w[pending sending]).none?
    end

    def within_fan_out
      previous = Thread.current[FAN_OUT]
      Thread.current[FAN_OUT] = true
      yield
    ensure
      Thread.current[FAN_OUT] = previous
    end

    def fan_out_active?
      Thread.current[FAN_OUT]
    end

    def record_chunk(recording, people)
      DeliveryStatus.record_chunk(recording, people)
    end

    def record_delivery(event)
      DeliveryStatus.record_delivery(event)
    end

    def finish(recording, actor)
      current = recording.reload
      return unless current.recordable.status == "sending" && finished?(current)

      Campaign.complete!(current, actor:)
    end

    def register_scope
      RecordingStudioNotifications.register_recipient_scope(SCOPE) do |context|
        SnapshotScope.new(recording: context.recording, actor: context.actor)
      end
    end

    def subscribe_deliveries
      ActiveSupport::Notifications.subscribe("deliver.recording_studio_notifications") do |*args|
        record_delivery(ActiveSupport::Notifications::Event.new(*args))
      end
    end

    def notify(recording, recipient, idempotency_key)
      broadcast = recording.recordable
      RecordingStudioNotifications.notify(
        notification_type: NOTIFICATION_TYPE, recipient:, idempotency_key:,
        title: broadcast.subject, body: broadcast.body,
        channels: [:email], inbox: false, deliver_later: false
      )
    end
    private_class_method :register_scope, :subscribe_deliveries, :notify
  end
end
