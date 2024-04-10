# frozen_string_literal: true

# Karafka should react to direct stop from commanding

setup_karafka
setup_web

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:is] = true
  end
end

draw_routes(Consumer)

elements = DT.uuids(1)
produce_many(DT.topic, elements)

Thread.new do
  sleep(0.1) until DT.key?(:is)

  Karafka::Web::Pro::Commanding::Dispatcher.command(
    :stop, ::Karafka::Web.config.tracking.consumers.sampler.process_id
  )
end

# Nothing needed. Won't stop unless commanding works
start_karafka_and_wait_until do
  false
end
