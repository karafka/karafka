# frozen_string_literal: true

# When topic in use is removed, Karafka may issue an `unknown_partition` error but even if, it
# should re-create the topic and move on.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"allow.auto.create.topics"] = true
  # Auto-create re-creates the topic, so deletion never becomes visible and admin gives up
  config.admin.max_retries_duration = 10_000
end

# A separate producer keeps writing to the topic while it is being deleted, so auto-create brings
# it back before every visibility check
KEEPER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.logger = Karafka::App.config.logger
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    # The keeper's messages arrive as further batches; start the delete under test only once
    return if DT.key?(:thread)

    DT[:keeper] = Thread.new do
      until DT.key?(:delete_finished)
        begin
          KEEPER.produce_async(topic: DT.topic, payload: "keep")
        rescue WaterDrop::Errors::ProduceError
          nil
        end

        sleep(0.05)
      end
    end

    DT[:thread] = Thread.new do
      # Kafka may show the deletion before auto-create brings the topic back, and then
      # `delete_topic` returns normally. We retry until one deletion never becomes visible.
      5.times do
        100.times do
          break if Karafka::Admin.cluster_info.topics.any? { |topic| topic[:topic_name] == DT.topic }

          sleep(0.1)
        end

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          Karafka::Admin.delete_topic(DT.topic)
          DT[:visible_deletions] << true
        rescue => e
          DT[:delete_error] = e
          DT[:delete_time] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
          break
        end
      end
    ensure
      DT[:delete_finished] = true
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

DT[:thread].join
DT[:keeper].join
KEEPER.close

admin = Karafka::App.config.admin
max_retries_duration = admin.max_retries_duration / 1_000.0
# One more retry may start right before the deadline, plus margin for a loaded runner
upper_bound = max_retries_duration + (admin.retry_backoff / 1_000.0) + 10

assert_equal Karafka::Errors::ResultNotVisibleError, DT[:delete_error].class
assert DT[:delete_time] >= max_retries_duration, DT[:delete_time]
assert DT[:delete_time] <= upper_bound, DT[:delete_time]

error = DT[:errors].first

exit unless error

assert(
  %i[unknown_partition unknown_topic_or_part].any?(error.code)
)
