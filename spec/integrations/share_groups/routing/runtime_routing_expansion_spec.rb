# frozen_string_literal: true

# When Karafka runs a share group (KIP-932), we should be able to inject new share group routes
# and they should be validated: valid ones are accepted and invalid ones raise an error.
# It does NOT mean they will be consumed (not yet).

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce_many(DT.topic, DT.uuids(10))

guarded = []

start_karafka_and_wait_until do
  next false if DT[:accepted].size < 10

  # Should not crash
  draw_routes(create_topics: false) do
    share_group "test2" do
      topic DT.topics[1] do
        consumer Consumer
      end
    end
  end

  [
    -> { max_wait_time(-2) },
    -> { acknowledgements(unacknowledged: :invalid) },
    -> { consumer Class.new(Karafka::BaseConsumer) }
  ].each do |invalid|
    draw_routes(create_topics: false) do
      share_group "regular" do
        topic DT.topics[2] do
          consumer Consumer
          instance_exec(&invalid)
        end
      end
    end
  rescue Karafka::Errors::InvalidConfigurationError
    guarded << true
  end

  true
end

assert_equal [true, true, true], guarded
assert Karafka::App.routes.map(&:name).include?("test2")
