# frozen_string_literal: true

module Karafka
  module TimeTrackers
    # Base class for all the time-trackers.
    class Base
      include ::Karafka::Core::Helpers::Time
    end
  end
end
