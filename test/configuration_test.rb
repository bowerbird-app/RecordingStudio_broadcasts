# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  Person = Struct.new(:email, :work_email)

  def setup
    @configuration = RecordingStudioBroadcasts::Configuration.new
  end

  def test_defaults
    assert_equal 100, @configuration.batch_size
    assert_equal "AdminRoot", @configuration.admin_root_type
  end

  def test_recipients_reads_email_from_a_symbol_or_a_proc
    person = Person.new("a@example.com", "b@example.com")

    @configuration.recipients(relation: -> { [person] })
    assert_equal "a@example.com", @configuration.recipients.email_for(person)

    @configuration.recipients(relation: -> { [person] }, email: lambda(&:work_email), name: lambda(&:email))
    assert_equal "b@example.com", @configuration.recipients.email_for(person)
    assert_equal [person], @configuration.recipients.relation.call
  end

  def test_recipients_must_be_configured_before_use
    assert_raises(RecordingStudioBroadcasts::Error) { @configuration.recipients }
  end

  def test_configure_yields_the_shared_configuration
    RecordingStudioBroadcasts.configure { |config| assert_same RecordingStudioBroadcasts.configuration, config }
  end
end
