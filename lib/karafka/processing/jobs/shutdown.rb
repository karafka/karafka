# frozen_string_literal: true

module Karafka
  module Processing
    module Jobs
      # Backwards-compatible alias — the real class moved to
      # {Karafka::Processing::ConsumerGroups::Jobs::Shutdown}.
      # @see ConsumerGroups::Jobs::Shutdown
      Shutdown = ConsumerGroups::Jobs::Shutdown
    end
  end
end
