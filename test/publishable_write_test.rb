# frozen_string_literal: true

require "test_helper"
require_relative "../app/models/recording_studio_broadcasts/publishable_write"

class PublishableWriteTest < Minitest::Test
  def setup
    ActiveSupport::IsolatedExecutionState.delete(RecordingStudioBroadcasts::PublishableWrite::KEY)
  end

  def test_nesting_keeps_the_outer_write_owned
    write = RecordingStudioBroadcasts::PublishableWrite

    refute_predicate write, :own_publishable_write?
    write.own_write do
      assert_predicate write, :own_publishable_write?
      write.own_write { assert_predicate write, :own_publishable_write? }
      assert_predicate write, :own_publishable_write?
    end
    refute_predicate write, :own_publishable_write?
  end

  def test_an_exception_clears_the_flag
    write = RecordingStudioBroadcasts::PublishableWrite

    assert_raises(RuntimeError) { write.own_write { raise "stopped" } }
    refute_predicate write, :own_publishable_write?
  end
end
