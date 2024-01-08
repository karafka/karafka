# frozen_string_literal: true

# When we decide to skip subscription group, it should skip all multiplexed sgs
Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  subscription_group :test do
    multiplexing(count: 10)

    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

ARGV[0] = 'server'
ARGV[1] = '--exclude-subscription-groups'
ARGV[2] = 'test'

failed = false

begin
  Karafka::Cli.start
rescue Karafka::Errors::InvalidConfigurationError
  failed = true
end

assert failed
