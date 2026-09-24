# frozen_string_literal: true

module Karafka
  # Legacy flat alias for the canonical {Karafka::Consumers::ConsumerGroup}. Kept for backwards
  # compatibility because it is the public base consumers inherit from and the class Pro injects
  # into. New code should reference `Consumers::ConsumerGroup`. Scheduled for retirement in
  # Karafka 3.0.
  BaseConsumer = Consumers::ConsumerGroup
end
