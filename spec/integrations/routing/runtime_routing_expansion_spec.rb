# frozen_string_literal: true

# When Karafka runs, we should be able to inject new routes and they should be picked
# It does NOT mean they will be used (not yet) but it should mean, that valid once are accepted
# and invalid are validated and an error is raised.
#
# This spec ensures, that dynamic routing expansions in runtime are subject to validation

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << message.offset
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(10)
produce_many(DT.topic, elements)

guarded = []

start_karafka_and_wait_until do
  if DT[0].size >= 10
    # Should not crash
    draw_routes do
      consumer_group "test2" do
        topic DT.topics[0] do
          consumer Consumer
        end
      end
    end

    begin
      draw_routes(create_topics: false) do
        consumer_group "regular" do
          topic DT.topics[1] do
            consumer Consumer
            max_wait_time(-2)
          end
        end
      end
    rescue Karafka::Errors::InvalidConfigurationError
      guarded << true
    end

    true
  else
    false
  end
end

assert_equal [true], guarded
assert Karafka::App.consumer_groups.map(&:name).include?("test2")
