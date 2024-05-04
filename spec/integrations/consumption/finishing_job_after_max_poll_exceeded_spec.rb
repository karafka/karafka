# frozen_string_literal: true

# While we cannot mark after max.poll.interval.ms kicked us out, Karafka should not break or
# stop in any way the job that was being executed

setup_karafka(allow_errors: %w[connection.client.poll.error]) do |config|
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
  config.max_messages = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:post)

    DT[:pre] << Time.now.to_f

    # Simulate too long running job
    sleep(15)

    # This should finish despite exceeding timeouts
    DT[:post] << Time.now.to_f
  end
end

draw_routes(Consumer)

produce(DT.topic, '')

start_karafka_and_wait_until do
  DT.key?(:post)
end

# Existence of this means, no "forceful" kill of worker or anything of that type
assert DT.key?(:post)

# It should have the needed lag on finishing beyond the max.poll.interval which is 10 seconds
assert DT[:post].first - DT[:pre].first >= 15
