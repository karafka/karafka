# frozen_string_literal: true

module Karafka
  module Processing
    # Our processing patterns differ depending on various features configurations
    # In this namespace we collect strategies for particular feature combinations to simplify the
    # design. Based on features combinations we can then select handling strategy for a given case.
    #
    # @note The lack of common code here is intentional. It would get complex if there would be
    #   any type of composition, so each strategy is expected to be self-sufficient
    module Strategies
    end
  end
end
