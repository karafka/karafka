# frozen_string_literal: true

module Karafka
  module Deserializing
    module Parallel
      # Immutable proxy passed to deserializers inside Ractor workers
      #
      # Data objects are frozen by default, making them automatically Ractor-shareable.
      # This replaces the full Karafka::Messages::Message (which is mutable and cannot
      # cross Ractor boundaries) with a minimal immutable snapshot of the data needed
      # for deserialization.
      #
      # Custom deserializers running inside Ractors can only access attributes defined here.
      MessageProxy = Data.define(:raw_payload)
    end
  end
end
