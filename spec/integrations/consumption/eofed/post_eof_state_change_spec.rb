# frozen_string_literal: true

# When we had an eof but then not, it should be reflected in the `#eofed?` status

setup_karafka do |config|
  config.kafka[:'enable.partition.eof'] = true
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { DT[:totals] << true }

    DT[:eofed] << eofed?
  end

  def eofed
    DT[:eofed] << eofed?
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  if DT.key?(:eofed)
    unless @produced
      @produced = true
      produce_many(DT.topic, DT.uuids(1000))
    end

    DT[:totals].size >= 100
  else
    false
  end
end

current = true
switch = false
DT[:eofed].each do |eof|
  unless switch && !eof
    current = eof
    switch = true
  end

  assert current
end
