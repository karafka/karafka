# frozen_string_literal: true

# Karafka should publish basic info when starting a subscription group
# This is useful for debugging

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
    DT[:done] << true
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

produce_many(DT.topics[0], DT.uuids(1))
produce_many(DT.topics[1], DT.uuids(1))

start_karafka_and_wait_until do
  DT[:done].size >= 2
end

$stdout = proper_stdout
$stderr = proper_stderr

content = strio.string

assert content.include?("[#{Karafka::Server.id}] Running in ruby")
assert content.include?("[#{Karafka::Server.id}] Running Karafka")
assert content.include?("[#{Karafka::Server.id}] Stopping Karafka server")
assert content.include?("[#{Karafka::Server.id}] Stopped Karafka server")

cg_id = DT.consumer_group
sg_id = Karafka::App.routes.first.subscription_groups.first.id

assert content.include?(
  "Group #{cg_id}/#{sg_id} subscribing to topics: #{DT.topics[0]}, #{DT.topics[1]}"
)
