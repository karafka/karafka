# frozen_string_literal: true

# When fenced out by a new instance, kubernetes listener should report this as a 500

INSTANCE_ID = SecureRandom.uuid

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'group.instance.id'] = INSTANCE_ID
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] = true
  end
end

draw_routes(Consumer)
produce_many(DT.topic, DT.uuids(1))

# This one (our current one) will be fenced out by the fork
fenced = Thread.new do
  start_karafka_and_wait_until do
    DT[:probing].include?('500')
  end
end

# Wait until anything is consumed so we are sure of the assignment
sleep(0.1) until DT.key?(0)

# Fork it so fencing will be triggered
pid = fork do
  # Wait in fork before starting processing so the liveness listener can open a tcp connection
  sleep(2)
  start_karafka_and_wait_until do
    false
  end
end

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
  hostname: '127.0.0.1',
  port: 9013,
  polling_ttl: 1_000
)

# Force start to bypass the regular lifecycle since we do not want fork to have it
listener.send(:start)

Karafka.monitor.subscribe(listener)

Thread.new do
  until Karafka::App.stopping?
    sleep(1)
    uri = URI.parse('http://127.0.0.1:9013/')
    response = Net::HTTP.get_response(uri)
    puts "Health check response: #{response.code}"
    DT[:probing] << response.code
  end
end

sleep(0.1) until DT[:probing].include?('500')

# Terminate the fork as it is no longer needed
# We do not care about its state as we're done testing
Process.kill(9, pid)
Process.wait(pid)

fenced.join

assert DT[:probing].include?('204')
assert DT[:probing].include?('500')
