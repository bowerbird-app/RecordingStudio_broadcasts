# frozen_string_literal: true

require "test_helper"
require_relative "../app/models/recording_studio_broadcasts/publishable_write"

class PublishableWriteTest < Minitest::Test
  Recording = Struct.new(:id)

  def setup
    ActiveSupport::IsolatedExecutionState.delete(RecordingStudioBroadcasts::PublishableWrite::KEY)
    @left = Recording.new("left")
    @right = Recording.new("right")
  end

  def test_nesting_keeps_each_recording_owned
    write = RecordingStudioBroadcasts::PublishableWrite

    refute write.own_publishable_write?(@left)
    write.own_write(@left) do
      assert write.own_publishable_write?(@left)
      refute write.own_publishable_write?(@right)
      write.own_write(@right) do
        assert write.own_publishable_write?(@left)
        assert write.own_publishable_write?(@right)
      end
      assert write.own_publishable_write?(@left)
      refute write.own_publishable_write?(@right)
    end
    refute write.own_publishable_write?(@left)
    refute write.own_publishable_write?(@right)
  end

  def test_own_write_requires_a_recording
    write = RecordingStudioBroadcasts::PublishableWrite

    assert_raises(ArgumentError) { write.own_write { nil } }
    assert_raises(ArgumentError) { write.own_write([nil]) }
  end

  def test_a_nested_own_write_nil_keeps_the_outer_recording
    write = RecordingStudioBroadcasts::PublishableWrite

    write.own_write(@left) do
      assert_raises(ArgumentError) { write.own_write(nil) }
      assert write.own_publishable_write?(@left)
      assert_raises(ArgumentError) { write.own_write }
      assert write.own_publishable_write?(@left)
    end
  end

  def test_an_exception_clears_the_recording
    write = RecordingStudioBroadcasts::PublishableWrite

    assert_raises(RuntimeError) { write.own_write(@left) { raise "stopped" } }
    refute write.own_publishable_write?(@left)
  end
end
