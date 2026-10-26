# frozen_string_literal: true

# Karafka should not publish `no_offset` from the offset commit callback on `error.occurred`.
# Every commit with nothing new stored reports it, so it is not an error.

setup_karafka

Karafka::Instrumentation::Callbacks::ConsumerGroups::OffsetCommit.prepend(
  Module.new do
    def on_offsets_committed(error, tpl)
      DT[:results] << error&.code
      super
    end
  end
)

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:committed)

    DT[:committed] = true

    mark_as_consumed(messages.last)
    commit_offsets!
    # Nothing new is stored, so this async commit reports `no_offset`
    commit_offsets
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT[:results].include?(:no_offset)
end

assert DT[:results].include?(nil)
