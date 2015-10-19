module Karafka
  module Routing
    # Object responsible for storing controllers, topics and groups mappings
    # @note All the controllers must be loaded before we use it
    # @note It caches all the mappings after the first use
    class Mapper
      class << self
        # @return [Array<Controller>] descendants of Karafka::BaseController
        def controllers
          @controllers ||= validate(Karafka::BaseController.descendants)
        end

        # @return [Hash<Symbol, Controller>] hash where the key is equal to the topic
        #   and value represents a controller assigned to that topic
        # @example
        #   by_topics => { topic1: Topic1Controller }
        def by_topics
          controllers.map { |ctrl| [ctrl.topic.to_sym, ctrl] }.to_h
        end

        private

        # Checks if all the controllers meet all the requirements in terms of groups and topics
        # @raise [Karafka::Routing::Mapper::DuplicatedGroupError] raised when more than one
        #   controller have the same group assigned
        # @raise [Karafka::Routing::Mapper::DuplicatedTopicError] raised when more than one
        #   controller have the same topic assigned
        # @param controllers [Array<Controller>] Karafka controllers that we want to check
        # @return [Array<Controller>] all the controllers after validation
        # @example Validate all Karafka::BaseController descendants
        #   validate(Karafka::BaseController.descendants)
        def validate(controllers)
          validate_key(controllers, :group, Errors::DuplicatedGroupError)
          validate_key(controllers, :topic, Errors::DuplicatedTopicError)

          controllers
        end

        # @param controllers [Array<Controller>] Karafka controllers that we want to check
        # @param controller_key [Symbol] controller class key that we want to check for
        #   uniquness across all the provided controllers
        # @param error [Error] error that should be raised when something is not right
        # @raise [Error] raises a provided error when a given key is not uniqe across all
        #   the provided controllers
        def validate_key(controllers, controller_key, error)
          count_map = controllers.each_with_object(Hash.new(0)) do |controller, counts|
            counts[controller.public_send(controller_key)] += 1
          end

          count_map.each do |key, count|
            fail(error, key) if count > 1
          end
        end
      end
    end
  end
end
