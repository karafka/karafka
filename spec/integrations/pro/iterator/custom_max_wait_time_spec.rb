# frozen_string_literal: true

# Karafka should use the custom poll time when defined

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

elements = DT.uuids(20).map { |data| { value: data }.to_json }
produce_many(DT.topic, elements)

# When we set it to 5 seconds, because we do not limit the flow anyhow, after the last message
# we will wait those 5 seconds
iterator = Karafka::Pro::Iterator.new(DT.topic, max_wait_time: 5_000)

i = 0
time = nil
iterator.each do
  i += 1
  time = Time.now.to_f
end

assert Time.now.to_f - time > 5
assert_equal 20, i
