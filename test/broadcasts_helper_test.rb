# frozen_string_literal: true

require "test_helper"
require_relative "../app/helpers/recording_studio_broadcasts/broadcasts_helper"

class BroadcastsHelperTest < Minitest::Test
  Broadcast = Struct.new(:sent_at)

  def test_schedule_label_uses_sent_at
    helper = RecordingStudioBroadcasts::BroadcastsHelper

    assert_equal "Sent at", helper.schedule_label(Broadcast.new(Time.current))
    assert_equal "Sends at", helper.schedule_label(Broadcast.new(nil))
  end
end
