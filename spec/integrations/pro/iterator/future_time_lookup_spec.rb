# frozen_string_literal: true

# When we want to get something from the future and there is nothing, we should just stop

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

produce(DT.topic, '1')

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => { 0 => Time.now + 60 } }
)

# No checks needed as in case we would get something older, it will raise
iterator.each { raise }
