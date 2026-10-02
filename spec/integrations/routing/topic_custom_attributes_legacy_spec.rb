# frozen_string_literal: true

# Custom features written in the legacy (pre mode-namespaces) layout - with a flat `Topic` module
# and flat `Contracts::Topic` / `Contracts::ConsumerGroup` classes - must keep working: their
# topic DSL has to be reachable on consumer-group topics and their contracts have to keep running
# during draw.

setup_karafka

class LegacyCustomAttributes < Karafka::Routing::Features::Base
  # Legacy flat topic module (pre mode-namespaces convention)
  module Topic
    def legacy_attribute(value = 42)
      @legacy_attribute ||= value
    end

    def to_h
      super.merge(legacy_attribute: legacy_attribute).freeze
    end
  end

  # Legacy flat contracts namespace with the old class names
  module Contracts
    # Old-style topic contract
    class Topic < Karafka::Contracts::Base
      configure do |config|
        config.error_messages = { "legacy_attribute_format" => "must be a positive integer" }
      end

      required(:legacy_attribute) { |val| val.is_a?(Integer) && val.positive? }
    end
  end
end

LegacyCustomAttributes.activate

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attribute] = topic.legacy_attribute
  end
end

# The legacy DSL must work and the legacy contract must accept valid values
draw_routes(create_topics: true) do
  topic DT.topics[0] do
    consumer Consumer
    legacy_attribute(100)
  end
end

assert_equal 100, Karafka::App.routes.first.topics.first.legacy_attribute

# The legacy contract must actually run and reject invalid values
failed = false

begin
  Karafka::App.routes.draw do
    consumer_group "legacy-failing" do
      topic "legacy-invalid" do
        active(false)
        consumer Consumer
        legacy_attribute(-1)
      end
    end
  end
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed

produce(DT.topics[0], "{}")

start_karafka_and_wait_until do
  DT.key?(:attribute)
end

assert_equal 100, DT[:attribute]
