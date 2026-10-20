# frozen_string_literal: true

module RecordingStudioBroadcasts
  class ReconcilePublishableChangeJob < ActiveJob::Base
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    discard_on InvalidTransition

    # Publishable's Update has already committed. Drafting the broadcast is a second transaction.
    def perform(recording_id, editor_type = nil, editor_id = nil)
      Campaign.reconcile_external_publishable_change!(recording_id, editor_type, editor_id)
    end
  end
end
