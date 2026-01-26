# frozen_string_literal: true

# This code is suppose to run the spec correctly and should not crash

require_relative "karafka"
require "rspec"
require "rspec/autorun"
require "karafka/testing"
require "karafka/testing/rspec/helpers"

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

RSpec.configure do |config|
  config.include Karafka::Testing::RSpec::Helpers
end

RSpec.describe ExampleConsumer do
  subject(:consumer) { karafka.consumer_for(:example) }

  it "expect not to fail" do
    Karafka.producer.produce_async(
      topic: :example,
      payload: { foo: "bar" }.to_json,
      key: "test",
      headers: { "test" => "me" }
    )

    consumer.consume
  end
end
