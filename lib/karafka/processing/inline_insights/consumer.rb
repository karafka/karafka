# frozen_string_literal: true

module Karafka
  module Processing
    class InlineInsights < Base
      module ConsumerApi
        # @return [Hash] empty hash or hash with given partition insights if already present
        def insights
          Tracker.find(topic, partition)
        end

        # @return [Boolean] true if there are insights to work with, otherwise false
        def insights?
          Tracker.exists?(topic, partition)
        end

        def statistics
          insights
        end

        def statistics?
          insights?
        end
      end
    end
  end
end
