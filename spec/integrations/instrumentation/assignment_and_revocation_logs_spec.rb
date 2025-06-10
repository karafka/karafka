# frozen_string_literal: true

# Karafka should have the info level logging of assigned and revoked partitions

strio = StringIO.new

proper_stdout = $stdout
proper_stderr = $stderr

$stdout = strio
$stderr = strio

setup_karafka do |config|
  config.logger = Logger.new(strio)
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:done] = true
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 3)
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

$stdout = proper_stdout
$stderr = proper_stderr

str = strio.string

group_prefix = "Group #{DT.consumer_group} rebalance"

assert str.include?("#{group_prefix}: #{DT.topic}-[0,1,2] assigned")
assert str.include?("#{group_prefix}: #{DT.topic}-[0,1,2] revoked")
