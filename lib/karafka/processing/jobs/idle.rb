# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # Backwards-compatible alias — the real class moved to
      # {Karafka::Processing::ConsumerGroups::Jobs::Idle}.
      # @see ConsumerGroups::Jobs::Idle
      Idle = ConsumerGroups::Jobs::Idle
    end
  end
end
