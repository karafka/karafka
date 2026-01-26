# frozen_string_literal: true

# When topic in use is removed, Karafka may issue an `unknown_partition` error but even if, it
# should re-create the topic and move on.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = true
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:thread] = Thread.new do
      Karafka::Admin.delete_topic(DT.topic)
    rescue
      nil
    end

    sleep(1)

    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

error = DT[:errors].first

exit unless error

assert(
  %i[unknown_partition unknown_topic_or_part].any?(error.code)
)

DT[:thread].join
