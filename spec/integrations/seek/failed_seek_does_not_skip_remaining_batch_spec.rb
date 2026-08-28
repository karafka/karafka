# frozen_string_literal: true

# When a user seek raises (for example a time-based seek that cannot resolve an offset on a
# degraded cluster, raising InvalidTimeBasedOffsetError), the in-flight seek_offset must not be
# lost. `#seek` nils seek_offset before invoking `client.seek`; if `client.seek` then raises, the
# failure path pauses without seeking back (`pause(nil)`), the unprocessed remainder of the batch
# is never redelivered and the next successful marking commits past it - a silent skip.
#
# After a failed seek the batch must be retried from the last marked offset, so no message in the
# batch is skipped.

setup_karafka(allow_errors: true)

# Force the consumer's explicit seek to offset 3 to raise once at the client level, simulating a
# transient seek failure. Only the public `#seek` path is affected; the internal seek used by
# `#pause` (to move back on retry) goes through `internal_seek` and is left intact.
module FailingSeekOnce
  def seek(message)
    if message.offset == 3 && !DT.key?(:seek_failed)
      DT[:seek_failed] = true

      raise(Karafka::Errors::InvalidTimeBasedOffsetError)
    end

    super
  end
end

Karafka::Connection::Client.prepend(FailingSeekOnce)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # On the first encounter of offset 3, perform a seek that fails at the client level. The
      # earlier messages (0, 1, 2) have already been marked, so seek_offset points at 3
      if message.offset == 3 && !DT.key?(:sought)
        DT[:sought] = true

        seek(3)
      end

      DT[:processed] << message.offset
      mark_as_consumed(message)
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  # Once the seek has failed, publish a trailing sentinel (offset 10) so we have a deterministic
  # stop condition: in both the buggy and fixed flows the consumer eventually reaches offset 10
  if DT.key?(:seek_failed) && !DT.key?(:sentinel_produced)
    DT[:sentinel_produced] = true

    produce_many(DT.topic, DT.uuids(1))
  end

  DT[:processed].include?(10)
end

# None of the messages in the original batch may be skipped. Without the fix, offsets 3-9 are
# never processed (the failed seek left seek_offset nil, so the retry paused without seeking back)
skipped = (0..9).to_a - DT[:processed]

assert_equal(
  [],
  skipped,
  "messages skipped after a failed client seek: #{skipped}"
)

assert DT[:processed].include?(10)
