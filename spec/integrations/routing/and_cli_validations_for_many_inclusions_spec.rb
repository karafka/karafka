# frozen_string_literal: true

# Karafka should correctly load resources separated by spaces or commas in the CLI usage

setup_karafka

AM = Karafka::App.config.internal.routing.activity_manager

def redraw
  Karafka::App.routes.clear
  ARGV.clear
  AM.clear

  draw_routes(create_topics: false) do
    defaults { consumer Class.new }

    consumer_group :c1 do
      topic "t1"
    end

    consumer_group :c2 do
      topic "t2"

      subscription_group :s1 do
        topic "t3"
      end

      subscription_group :s2 do
        topic "t5"
      end

      subscription_group :s3 do
        topic "t6"
      end
    end

    consumer_group :c3 do
      topic "t4"
    end
  end

  yield

  Karafka::Cli.start
end

# We stub the server so we don't have to start Kafka connections as it is irrelevant in this
# particular flow of specs
#
# Instead of running it, we just perform needed validations
module Karafka
  class Server
    class << self
      def run
        Karafka::App.config.internal.cli.contract.validate!(
          AM.to_h
        )
      end
    end
  end
end

redraw do
  ARGV[0] = "server"
  ARGV[1] = "--topics"
  ARGV[2] = "t1,t2"
end

assert AM.active?(:topics, "t1")
assert AM.active?(:topics, "t2")
assert !AM.active?(:topics, "t3")

redraw do
  ARGV[0] = "server"
  ARGV[1] = "--exclude-topics"
  ARGV[2] = "t1"
end

assert !AM.active?(:topics, "t1")
assert AM.active?(:topics, "t2")
assert AM.active?(:topics, "t3")

redraw do
  ARGV[0] = "server"
  ARGV[1] = "--exclude-consumer-groups"
  ARGV[2] = "c1"
end

assert !AM.active?(:consumer_groups, "c1")
assert AM.active?(:consumer_groups, "c2")
assert AM.active?(:consumer_groups, "c3")

redraw do
  ARGV[0] = "server"
  ARGV[1] = "--exclude-consumer-groups"
  ARGV[2] = "c1,c2"
end

assert !AM.active?(:consumer_groups, "c1")
assert !AM.active?(:consumer_groups, "c2")
assert AM.active?(:consumer_groups, "c3")

redraw do
  ARGV[0] = "server"
  ARGV[1] = "--exclude-subscription-groups"
  ARGV[2] = "s1,s3"
end

assert !AM.active?(:subscription_groups, "s1")
assert !AM.active?(:subscription_groups, "s3")
assert AM.active?(:subscription_groups, "s2")

redraw do
  ARGV[0] = "server"
  ARGV[1] = "--include-subscription-groups"
  ARGV[2] = "s1,s3"
end

assert AM.active?(:subscription_groups, "s1")
assert AM.active?(:subscription_groups, "s3")
assert !AM.active?(:subscription_groups, "s2")
