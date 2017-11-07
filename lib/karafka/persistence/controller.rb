# frozen_string_literal: true

module Karafka
  # Module used to provide a persistent cache layer for Karafka components that need to be
  # shared inside of a same thread
  module Persistence
    # Module used to provide a persistent cache across batch requests for a given
    # topic and partition to store some additional details when the persistent mode
    # for a given topic is turned on
    class Controller
      # Thread.current scope under which we store controllers data
      PERSISTENCE_SCOPE = :controllers

      class << self
        # @return [Hash] current thread persistence scope hash with all the controllers
        def all
          Thread.current[PERSISTENCE_SCOPE] ||= {}
        end

        # Used to build (if block given) and/or fetch a current controller instance that will be
        #   used to process messages from a given topic and partition
        # @return [Karafka::BaseController] base controller descendant
        # @param topic [Karafka::Routing::Topic] topic instance for which we might cache
        # @param partition [Integer] number of partition for which we want to cache
        def fetch(topic, partition)
          all[topic.id] ||= {}

          # We always store a current instance
          if topic.persistent
            all[topic.id][partition] ||= yield
          else
            all[topic.id][partition] = yield
          end
        end
      end
    end
  end
end
