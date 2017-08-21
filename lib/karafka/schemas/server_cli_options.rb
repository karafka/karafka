# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for validating correctness of the server cli command options
    # We validate some basics + the list of topics on which we want to listen, to make
    # sure that all of them are defined, plus that a pidfile does not exist
    ServerCliOptions = Dry::Validation.Schema do
      configure do
        option :topics

        def self.messages
          super.merge(
            en: {
              errors: {
                topics_inclusion: 'Unknown topics that don\'t match any from the routing.',
                pid_existence: 'Pidfile already exists.'
              }
            }
          )
        end
      end

      optional(:pid).filled(:str?)
      optional(:daemon).filled(:bool?)
      optional(:topics).filled(:array?)

      validate(topics_inclusion: :topics) do |topics|
        # If there were no topics declared in the server cli, it means that we will run all of
        # them and no need to validate them here at all
        if topics.nil?
          true
        else
          (topics - Karafka::Routing::Builder.instance.map(&:topics).flatten.map(&:name)).empty?
        end
      end

      validate(pid_existence: :pid) do |pid|
        pid ? !File.exist?(pid) : true
      end
    end
  end
end
