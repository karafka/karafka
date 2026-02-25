# frozen_string_literal: true

# This code is suppose to run the spec correctly and should not crash

require "active_support"
require "active_support/test_case"
require "minitest"
require "minitest/autorun"
require "mocha/minitest"
require_relative "karafka"
require "karafka/testing/minitest/helpers"

Karafka::App.setup

class ExampleConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      raise unless message.payload == { "foo" => "bar" }
      raise unless message.key == "test"
      raise unless message.headers == { "test" => "me" }

      message.metadata

      mark_as_consumed(message)
    end
  end
end

class Test < ActiveSupport::TestCase
  include Karafka::Testing::Minitest::Helpers

  def setup
    @consumer = @karafka.consumer_for(:example)
  end

  test "consume" do
    Karafka.producer.produce_async(
      topic: :example,
      payload: { foo: "bar" }.to_json,
      key: "test",
      headers: { "test" => "me" }
    )

    @consumer.consume
  end
end

Minitest.run
