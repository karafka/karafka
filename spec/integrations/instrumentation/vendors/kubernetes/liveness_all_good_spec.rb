# frozen_string_literal: true

# When all good, all should be ok

require 'net/http'
require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

# Raise consumer error, just to make sure this does not impact liveness
setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    unless @raised
      @raised = true
      raise StandardError
    end

    DT[0] << true
  end
end

begin
  port = rand(3000..5000)
  listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(
    hostname: '127.0.0.1',
    port: port
  )
rescue Errno::EADDRINUSE
  retry
end

Karafka.monitor.subscribe(listener)

Thread.new do
  until Karafka::App.stopping? do
    sleep(0.1)
    uri = URI.parse("http://127.0.0.1:#{port}/")
    response = Net::HTTP.get_response(uri)
    DT[:probing] << response.code
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[0].size >= 1
end

assert DT[:probing].include?('204')
assert !DT[:probing].include?('500')
