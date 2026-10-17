# frozen_string_literal: true

require "test_helper"

class FilterRegistryTest < Minitest::Test
  Person = Struct.new(:name, :plan, :age)

  def setup
    @registry = RecordingStudioBroadcasts::FilterRegistry.new
    @people = [Person.new("ann", "pro", 40), Person.new("bob", "pro", 20), Person.new("cy", "free", 50)]
  end

  def test_filters_combine_with_and_and_skip_blank_or_unknown_values
    @registry.register(:plan, label: "Plan") { |scope, value| scope.select { |person| person.plan == value } }
    @registry.register(:older_than, label: "Older than", input: :number) do |scope, value|
      scope.select { |person| person.age > value.to_i }
    end

    assert_equal %w[ann], names(@registry.apply(@people, "plan" => "pro", "older_than" => "30"))
    assert_equal %w[ann bob], names(@registry.apply(@people, plan: "pro", older_than: ""))
    assert_equal %w[ann bob cy], names(@registry.apply(@people, "missing" => "x"))
    assert_equal %w[ann bob cy], names(@registry.apply(@people, nil))
  end

  def test_registering_a_key_again_replaces_it
    @registry.register(:plan, label: "Plan") { |scope, _value| scope.first(1) }
    @registry.register("plan", label: "Plan tier", input: :select, options: %w[pro free]) do |scope, value|
      scope.select { |person| person.plan == value }
    end

    assert_equal ["Plan tier"], @registry.all.map(&:label)
    assert_equal %i[select], @registry.all.map(&:input)
    assert_equal %w[cy], names(@registry.apply(@people, plan: "free"))
  end

  def test_register_requires_a_block
    assert_raises(ArgumentError) { @registry.register(:plan, label: "Plan") }
  end

  private

  def names(people)
    people.map(&:name)
  end
end
