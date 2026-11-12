# frozen_string_literal: true

require "test_helper"

class ApiRegistrationTest < Minitest::Test
  def test_one_availability_check
    api = File.read(File.expand_path("../lib/recording_studio_broadcasts/api.rb", __dir__))
    api_dir = File.expand_path("../lib/recording_studio_broadcasts/api", __dir__)
    lib = Dir["#{api_dir}/**/*.rb"].map { |path| File.read(path) }.join

    assert_equal 1, api.scan("def recording_studio_api_available?").size
    refute_includes lib, "defined?(RecordingStudioApi)"
    refute_includes lib, "respond_to?(:register"
  end

  def test_campaign_api_is_operations_only_without_publishable_auto_actions
    registration = File.read(File.expand_path("../lib/recording_studio_broadcasts/api/registration.rb", __dir__))

    assert_includes registration, "auto_capability_actions: false"
    assert_includes registration, "api: OPERATIONS_API"
    assert_includes registration, "capability_actions: CAPABILITY_ACTIONS"
    refute_includes registration, "api: :public"
  end

  def test_engine_registers_the_api
    engine = File.read(File.expand_path("../lib/recording_studio_broadcasts/engine.rb", __dir__))

    assert_includes engine, "RecordingStudioBroadcasts::Api.register!"
  end
end
