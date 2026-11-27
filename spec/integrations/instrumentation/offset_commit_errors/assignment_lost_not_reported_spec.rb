# frozen_string_literal: true

# Karafka should not publish on `error.occurred` a commit made after the assignment was lost.
# `commit_offsets!` returns false for it, and the offset commit callback gets the same result,
# which is not an error for Karafka.

setup_karafka(
  # Exceeding the max poll interval is expected and reported
  allow_errors: %w[connection.client.poll.error]
) do |config|
  config.max_messages = 1
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

# Probe: with this method, rdkafka also passes the result of every commit to the callback
Karafka::Instrumentation::Callbacks::ConsumerGroups::OffsetCommit.prepend(
  Module.new do
    def on_offsets_committed(error, _tpl)
      DT[:results] << error&.code
    end
  end
)

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:committed)

    mark_as_consumed(messages.last)
    # Exceed the max poll interval, so the assignment is lost before the commit
    sleep(15)
    DT[:committed] = commit_offsets!
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT[:results].include?(:assignment_lost)
end

assert_equal false, DT[:committed]
