# frozen_string_literal: true

# When running work of a single consumer group from many subscription groups, upon shutdown we
# should not experience any rebalance problems as the shutdown should happen after all the work
# is done.

require 'stringio'

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

setup_karafka do |config|
  config.logger = Logger.new(strio)
  config.concurrency = 10
end

POLL = Concurrent::Array.new(6) { |i| i }
POLL << 8
POLL.reverse!

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:clients] << client.object_id
    sleep POLL.pop || 2
  end
end

draw_routes do
  DT.topics.first(10).each_slice(2) do |topics|
    slice_uuid = SecureRandom.uuid

    subscription_group slice_uuid do
      topics.each do |topic_name|
        topic topic_name do
          consumer Consumer
        end
      end
    end
  end
end

messages = DT.topics.first(10).map do |topic_name|
  { topic: topic_name, payload: '1' }
end

Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:clients].uniq.count >= 5 && sleep(5)
end

$stdout = proper_stdout
$stderr = proper_stderr

assert_equal false, strio.string.include?('Timed out'), strio.string
