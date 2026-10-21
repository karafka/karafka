# frozen_string_literal: true

# Share group (KIP-932) partitions are processed in parallel: a long running consumption of one
# partition does not delay the processing of another partition records received in the same poll.

setup_karafka

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  partitions = []
  event[:messages_buffer].each { |_, partition, _| partitions << partition }

  DT[:polls] << partitions.sort unless partitions.empty?
end

class Consumer < Karafka::ShareConsumer
  def consume
    # The next poll happens only once all the jobs of the previous one are done, so this is the
    # poll this batch comes from
    poll = DT[:polls].size
    started_at = Time.now.to_f

    if DT[:polls].last == [0, 1]
      # Slow down partition 0 once, when a poll got records of both partitions
      if messages.metadata.partition.zero? && !DT.key?(:slow_poll)
        DT[:slow_poll] = poll
        sleep(3)
      end
    else
      # A single partition poll: give the other partition records time to be prefetched, so a
      # next poll gets records of both partitions
      sleep(0.5)
    end

    DT[:batches] << [poll, messages.metadata.partition, started_at, Time.now.to_f]

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

setup_share_group(DT.topic, DT.group, 2)

elements = []

# Keep producing to both partitions until one poll gets records of both of them
start_karafka_and_wait_until do
  unless DT.key?(:slow_poll) || elements.size >= 200
    2.times do |partition|
      payload = SecureRandom.uuid
      elements << payload
      produce(DT.topic, payload, partition: partition)
    end

    sleep(0.2)
  end

  DT.key?(:slow_poll) && DT[:accepted].uniq.size >= elements.size
end

assert_equal elements.sort, DT[:accepted].uniq.sort

slow = DT[:batches].find { |poll, partition, _, _| poll == DT[:slow_poll] && partition.zero? }
fast = DT[:batches].find { |poll, partition, _, _| poll == DT[:slow_poll] && partition == 1 }

assert slow[3] - slow[2] >= 3
# The other partition batch was fully processed while the slow one was still running
assert fast[2] < slow[3]
assert fast[3] < slow[3]
