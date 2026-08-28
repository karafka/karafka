# frozen_string_literal: true

# Makes sure a `#consume` call sees the whole expected batch at once, just not to deal with edge
# cases. Kafka can ship only a few messages in the first fetch, which makes any test whose logic
# depends on batch composition (virtual partitions distribution, in-batch sync/async split, single
# large transaction, ...) non-reproducible. This filter seeks back until at least `min` messages are
# available in a single poll, so the batch always arrives whole.
#
# @note Originally written for virtual partition specs (hence the historical `VpStabilizer` name),
#   it is now used by any spec that needs a full, deterministic batch.
#
# @note This filter is loaded by `spec_helper` before `Karafka::Pro` is required, so it cannot
#   inherit `Filters::Base`. It therefore defines the `#pause?` / `#seek?` / `#skip?` predicates
#   (that the applier resolves actions through) inline instead of getting them from the base.
class FlowStabilizer
  class << self
    # Builds the stabilizer
    def call(*)
      new
    end
  end

  attr_reader :cursor

  # By default wait for batch of 100 to be shipped
  # @param min [Integer] number of messages to wait on
  def initialize(min = 100)
    @min = min
    super()
  end

  # Back off until enough data
  #
  # @param messages [Array<Karafka::Messages::Message>]
  def apply!(messages)
    @applied = false
    @cursor = nil

    return if messages.size >= @min

    @cursor = messages.first
    messages.clear
    @applied = true
  end

  # @return [Integer]
  def timeout
    0
  end

  # @return [Boolean]
  def applied?
    @applied
  end

  # @return [Symbol]
  def action
    applied? ? :seek : :skip
  end

  # @return [Boolean]
  def pause?
    action == :pause
  end

  # @return [Boolean]
  def seek?
    action == :seek
  end

  # @return [Boolean]
  def skip?
    action == :skip
  end

  # @return [Boolean]
  def mark_as_consumed?
    false
  end
end
