# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Named recipient scope for notify_fan_out. Each chunk re-reads pending
  # snapshot rows, so cancel skips anyone not already loaded into that chunk.
  class SnapshotScope
    def initialize(recording:, actor:)
      @recording = recording
      @actor = actor
    end

    def except(*)
      self
    end

    def find_in_batches(batch_size:, **, &block)
      Delivery.within_fan_out do
        walk(batch_size, &block)
        Delivery.finish(@recording, @actor)
      end
    end

    private

    def walk(batch_size, &block)
      after_id = nil
      loop do
        batch = pending_batch(after_id, batch_size)
        break if batch.empty?

        after_id = batch.last.first
        hand_off(batch.map(&:last), &block)
      end
    end

    def pending_batch(after_id, batch_size)
      scope = Recipient.where(recording_id: @recording.id, status: "pending").order(:id).limit(batch_size)
      scope = scope.where(Recipient.arel_table[:id].gt(after_id)) if after_id
      scope.pluck(:id, :recipient_id)
    end

    def hand_off(recipient_ids)
      people = still_pending(recipient_ids)
      return if people.empty?

      yield people
      Delivery.record_chunk(@recording, people)
    end

    def still_pending(recipient_ids)
      ids = Recipient.where(recording_id: @recording.id, status: "pending", recipient_id: recipient_ids)
                     .pluck(:recipient_id)
      model.where(id: ids).to_a
    end

    def model
      RecordingStudioBroadcasts.configuration.recipients.relation.call.klass
    end
  end
end
