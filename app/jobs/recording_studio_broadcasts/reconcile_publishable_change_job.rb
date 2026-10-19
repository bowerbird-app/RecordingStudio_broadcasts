# frozen_string_literal: true

module RecordingStudioBroadcasts
  class ReconcilePublishableChangeJob < ActiveJob::Base
    queue_as :default

    # Publishable's Update has already committed. Drafting the broadcast is a second transaction.
    def perform(recording_id)
      Campaign.reconcile_external_publishable_change!(recording_id)
    end
  end
end
