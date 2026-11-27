# frozen_string_literal: true

# Karafka should not take successful offset commits from rdkafka when nothing subscribes to
# `client.offsets.committed`, so their offsets are not converted to Ruby.

setup_karafka

# Counts the successful commits that rdkafka passes to Karafka
module SucceededCounter
  def on_offsets_commit_succeeded(tpl)
    DT[:succeeded] << true

    super
  end
end

Karafka::Instrumentation::Callbacks::ConsumerGroups::OffsetCommit.prepend(SucceededCounter)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:committed] << mark_as_consumed!(messages.last)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:committed].size >= 1
end

assert_equal [true], DT[:committed].uniq
assert DT[:succeeded].empty?
