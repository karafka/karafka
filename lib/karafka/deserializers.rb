# frozen_string_literal: true

module Karafka
  # Legacy flat alias for the canonical {Karafka::Deserializing::Deserializers}. Kept for
  # backwards compatibility because the default deserializers are referenced by this name in user
  # routing. New code should reference `Deserializing::Deserializers`. Scheduled for retirement in
  # Karafka 3.0.
  Deserializers = Deserializing::Deserializers
end
