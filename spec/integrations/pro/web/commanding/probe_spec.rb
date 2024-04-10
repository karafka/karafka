# frozen_string_literal: true

# Karafka should react to probing and should create probe result in the commands topic

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
    :probe, ::Karafka::Web.config.tracking.consumers.sampler.process_id
  )

  loop do
    result = Karafka::Admin.read_topic(
      ::Karafka::Web.config.topics.consumers.commands,
      0,
      1
    ).first

    if result && result.payload[:type] == 'result'
      DT[:ready] = true

      break
    end

    sleep 1
  end
end

start_karafka_and_wait_until do
  DT.key?(:ready)
end
