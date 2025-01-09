# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Just a simple UTC day implementation.
      # Since we operate on a scope of one day, this allows us to encapsulate when given day ends
      class Day
        # @return [Integer] utc timestamp when this day object was created. Keep in mind, that
        #   this is **not** when the day started but when this object was created.
        attr_reader :created_at
        # @return [Integer] utc timestamp when this day ends (last second of day).
        # Equal to 23:59:59.
        attr_reader :ends_at
        # @return [Integer] utc timestamp when this day starts. Equal to 00:00:00
        attr_reader :starts_at

        def initialize
          @created_at = Time.now.to_i

          time = Time.at(@created_at).utc

          @starts_at = Time.utc(time.year, time.month, time.day).to_i
          @ends_at = @starts_at + 86_399
        end

        # @return [Boolean] did the current day we operate on ended.
        def ended?
          @ends_at < Time.now.to_i
        end
      end
    end
  end
end
