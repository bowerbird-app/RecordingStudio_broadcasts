# frozen_string_literal: true

require "test_helper"

class BroadcastClaimTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    reset_tables!
    RecordingStudioBroadcasts.configuration.batch_size = 2
    3.times { |index| create_user("claim#{index}@example.com") }
    @recording = create_broadcast
    RecordingStudioBroadcasts.launch(@recording, actor: nil)
  end

  teardown do
    RecordingStudioBroadcasts.configuration.batch_size = 100
    reset_tables!
  end

  test "two workers claiming at the same time never get the same person" do
    first = second = nil

    RecordingStudioBroadcasts::Recipient.transaction do
      first = RecordingStudioBroadcasts::Delivery.claim(@recording).map(&:id)
      second = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.transaction do
            # Waiting on the first worker's rows would deadlock this test, so fail fast instead.
            connection.execute("SET LOCAL lock_timeout = '2s'")
            RecordingStudioBroadcasts::Delivery.claim(@recording).map(&:id)
          end
        end
      end.value
    end

    assert_equal [ 2, 1 ], [ first.size, second.size ]
    assert_empty first & second
  end
end
