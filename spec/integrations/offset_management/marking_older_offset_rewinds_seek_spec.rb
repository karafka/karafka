# frozen_string_literal: true

# Marking an offset older than the one already marked is supported and intentional (#2432 - "allow
# marking older offsets to support advanced rewind capabilities"). Marking rewinds the in-memory
# seek offset, so a subsequent seek/retry resumes from the older position rather than only ever
# moving forward.
#
# Here we mark the last offset of the batch and then an older one; a raised error makes Karafka
# pause and seek back to the (now rewound) seek offset, so the retry reprocesses from the older
# offset. Only re-marking the exact current offset is ignored (to avoid erasing stored metadata) -
# genuinely older offsets must go through.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    # Rewind only once; after the retry we let processing settle
    return if DT.key?(:rewound)

    mark_as_consumed!(messages.last)

    # Mark an offset older than the one we just marked - this must rewind the seek offset
    older = messages.find { |message| message.offset == 4 }
    mark_as_consumed!(older)

    DT[:rewound] = true

    # Forces a pause and a seek back to the (now rewound) seek offset
    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management(true)
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  # First pass 0..9, then the reprocessed 5..9 after the rewind
  DT[:offsets].size >= 15
end

# First pass processed the whole batch
assert_equal((0..9).to_a, DT[:offsets].first(10))

# Marking offset 4 rewound the seek offset to 5, so the error retry reprocessed 5..9 - proving
# older offsets can be marked (and are not ignored as "already moved past")
assert_equal((5..9).to_a, DT[:offsets][10, 5])
