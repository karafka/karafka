# frozen_string_literal: true

# The result of `#commit_offsets!` is documented as a fencing signal: true means the sync commit
# went through and we still own the partition, so it can gate external side effects like DB
# transaction commits. When the assignment is lost (e.g. max.poll.interval.ms exceeded during
# processing) and the commit FAILS because of it, the method must NOT report true.
#
# We call `#commit_offsets!` in a tight loop across the max.poll.interval.ms expiry so one call
# brackets the exact moment the assignment loss surfaces: entry revocation check passes, the
# commit itself is rejected by the broker, and the post-commit revocation check observes the
# loss (revoking the coordinator as its side effect). For such a call, returning true is a
# broken contract.
#
# Two true results are NOT violations and are deliberately permitted:
# - a commit the broker accepted just before the loss landed: the fence held at acceptance
#   time, offsets are durably committed and the new owner resumes past them, so reporting
#   false would invite a rollback-after-commit (lost side effects)
# - a vacuous client-side success with nothing pending: not broker-validated, fenced one
#   level earlier by the marking result
# Both leave the coordinator untouched, so the violation signature is precisely: result true
# while this very call's revocation check revoked the coordinator (the failed-commit path).
#
# @note This spec races a real broker: whether the in-flight commit at the loss moment gets
#   rejected (the bug path) or was accepted just before (legitimate race) is a broker-side
#   race. With three loss cycles per run it illustrates the bug in a substantial fraction of
#   runs - a single red run is a proof, green runs are inconclusive.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
  config.max_messages = 1
end

# One assignment loss per cycle; multiple cycles compound the capture probability. The
# commit rejection at the loss moment is the rarer outcome of the broker-side race, hence
# more cycles than in the marking sibling spec
CYCLES = 5

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT[:cycles].size >= CYCLES

    # Keep committing until well past max.poll.interval.ms, so the loop is guaranteed to be
    # mid-call when the assignment loss surfaces
    finish_at = Time.now + 15
    post_loss_calls = 0
    offset_to_store = 0

    while Time.now < finish_at
      lost_before = client.assignment_lost?

      # Store a NEW offset on every iteration so each sync commit performs a real broker
      # round-trip. Re-committing an unchanged offset short-circuits client-side as a vacuous
      # success and would never exercise the broker-rejected (illegal generation) path
      offset_to_store += 1
      client.mark_as_consumed(
        Karafka::Messages::Seek.new(topic.name, partition, offset_to_store)
      )

      result = commit_offsets!
      lost_after = client.assignment_lost?
      coordinator_revoked = coordinator.revoked?

      DT[:calls] << [lost_before, result, lost_after, coordinator_revoked]

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
assert DT[:calls].any? { |_, _, lost_after, _| lost_after }, "assignment was never lost"

# There must be post-loss samples proving the loop kept exercising the lost state
post_loss = DT[:calls].drop_while { |_, _, lost_after, _| !lost_after }
assert post_loss.size >= 2, "expected multiple post-loss samples"

# Contract: a call whose own revocation check observed the loss (and revoked the coordinator)
# must never report true. A true here means user code would commit a DB transaction believing
# the offsets were durably committed while the partition is already reassigned and the commit
# was rejected.
violations = DT[:calls].select do |_, result, _, coordinator_revoked|
  result && coordinator_revoked
end

assert(
  violations.empty?,
  "commit_offsets! returned true while its own check observed the lost partition " \
  "#{violations.size} time(s)"
)
