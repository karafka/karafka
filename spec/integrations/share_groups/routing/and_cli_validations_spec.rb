# frozen_string_literal: true

# The server CLI share group (KIP-932) filters should work end-to-end through `Karafka::Cli`:
# unknown share groups are rejected for both inclusions and exclusions, many share groups can be
# passed separated by commas, and the subscription group and topic filters recognize share group
# subscription groups and topics.

setup_karafka

AM = Karafka::App.config.internal.routing.activity_manager

# We stub the server so we don't have to start Kafka connections as it is irrelevant in this
# particular flow of specs. Instead of running it, we just perform needed validations
module Karafka
  class Server
    class << self
      def run
        Karafka::App.config.internal.cli.contract.validate!(AM.to_h)
      end
    end
  end
end

def redraw(*args)
  clear_app_draws
  AM.clear

  draw_routes(create_topics: false) do
    defaults { consumer Class.new(Karafka::ShareConsumer) }

    share_group :s1 do
      topic "t1"
    end

    share_group :s2 do
      subscription_group :sub1 do
        topic "t2"
      end
    end

    share_group :s3 do
      topic "t3"
    end
  end

  ARGV.replace(["server", *args])

  Karafka::Cli.start
ensure
  ARGV.clear
end

errors = []

[
  ["--include-share-groups", "Unknown share group name"],
  ["--exclude-share-groups", "Unknown share group name"],
  ["--include-subscription-groups", "Unknown subscription group name"],
  ["--exclude-topics", "Unknown topic name"]
].each do |flag, message|
  redraw(flag, "non-existing")
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?(message), e.message

  errors << flag
end

assert_equal 4, errors.size

redraw("--include-share-groups", "s1,s3")

assert AM.active?(:share_groups, "s1")
assert !AM.active?(:share_groups, "s2")
assert AM.active?(:share_groups, "s3")

redraw("--exclude-share-groups", "s1,s2")

assert !AM.active?(:share_groups, "s1")
assert !AM.active?(:share_groups, "s2")
assert AM.active?(:share_groups, "s3")

# Share group names are a separate scope from the consumer group ones
redraw("--share-groups", "s2")

assert AM.active?(:share_groups, "s2")
assert AM.active?(:consumer_groups, "s1")

redraw("--include-subscription-groups", "sub1")

assert_equal %w[s2], Karafka::App.subscription_groups.keys.map(&:name)

redraw("--topics", "t1,t3")

assert_equal %w[s1 s3], Karafka::App.subscription_groups.keys.map(&:name)
