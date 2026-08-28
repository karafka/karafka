# frozen_string_literal: true

# The results of `#mark_as_consumed` and `#mark_as_consumed!` are documented as ownership
# signals: "False indicates that we were not able and that we have lost the partition". When
# the assignment is lost (e.g. max.poll.interval.ms exceeded during processing) and the
# marking fails because of it, the methods must NOT report true - the bang variant exists
# precisely to confirm durable marking for fencing purposes.
#
# We mark in a tight loop (with advancing offsets, so every bang call performs a real broker
# round-trip) across the max.poll.interval.ms expiry, so one call brackets the exact moment
# the loss surfaces: entry revocation check passes, the store/commit fails, and the
# post-failure revocation check observes the loss (revoking the coordinator as its side
# effect). For such a call, returning true is a broken contract.
#
# A marking that succeeded just before the loss landed leaves the coordinator untouched and
# its true result is legitimate, so the violation signature is precisely: result true while
# this very call's revocation check revoked the coordinator (the failed-marking path).
#
# @note This spec races a real broker: whether the in-flight operation at the loss moment gets
#   rejected (the bug path) or was accepted just before (legitimate race) is a broker-side
#   race. With three loss cycles per run it illustrates the bug in a substantial fraction of
#   runs - a single red run is a proof, green runs are inconclusive.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.max_messages = 1
end

# One assignment loss per cycle; multiple cycles compound the capture probability
CYCLES = 3

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:cycles].size >= CYCLES

    # Keep marking until well past max.poll.interval.ms, so the loop is guaranteed to be
    # mid-call when the assignment loss surfaces
    finish_at = Time.now + 15
    post_loss_calls = 0
    offset_to_mark = 0

    while Time.now < finish_at
      # Advancing offsets keep each bang marking a real broker round-trip instead of a
      # client-side no-op
      offset_to_mark += 1
      seek_message = Karafka::Messages::Seek.new(topic.name, partition, offset_to_mark)

      # Exercise both documented methods
      method = offset_to_mark.odd? ? :mark_as_consumed! : :mark_as_consumed

      lost_before = client.assignment_lost?
      result = public_send(method, seek_message)
      lost_after = client.assignment_lost?
      coordinator_revoked = coordinator.revoked?

      DT[:calls] << [method, lost_before, result, lost_after, coordinator_revoked]

      if lost_after
        post_loss_calls += 1

        # Enough post-loss samples to prove the steady state - no need to spin the full window
        break if post_loss_calls >= 50
      end
    end

    DT[:cycles] << true
  end
end

draw_routes(Consumer)

produce(DT.topic, "")

start_karafka_and_wait_until do
  DT[:cycles].size >= CYCLES
end

# The assignment loss must have happened (otherwise this spec proves nothing)
assert DT[:calls].any? { |_, _, _, lost_after, _| lost_after }, "assignment was never lost"

# There must be post-loss samples proving the loop kept exercising the lost state
post_loss = DT[:calls].drop_while { |_, _, _, lost_after, _| !lost_after }
assert post_loss.size >= 2, "expected multiple post-loss samples"

# Contract: a call whose own revocation check observed the loss (and revoked the coordinator)
# must never report true. A true here means user code following the documented
# stop-on-revocation pattern keeps processing a lost partition believing the offsets were
# durably stored.
violations = DT[:calls].select do |_, _, result, _, coordinator_revoked|
  result && coordinator_revoked
end

assert(
  violations.empty?,
  "marking returned true while its own check observed the lost partition: " \
  "#{violations.map(&:first).tally}"
)
