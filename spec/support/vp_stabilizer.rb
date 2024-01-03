# frozen_string_literal: true

# Makes sure we get 100 messages in VPs just not to deal with edge cases
# Kafka can sometimes ship few messages in first fetch and this makes things complicated to test
# parallel operations on VPs with reproducible env. This filter ensures we wait until we get all
# that we needed
class VpStabilizer < Karafka::Pro::Processing::Filters::Base
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
end
