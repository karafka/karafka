# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for validating correctness of the server cli command options
    # We validate some basics + the list of consumer_groups on which we want to use, to make
    # sure that all of them are defined, plus that a pidfile does not exist
    ServerCliOptions = Dry::Validation.Schema do
      configure do
        option :consumer_groups

        def self.messages
          super.merge(
            en: {
              errors: {
                consumer_groups_inclusion: 'Unknown consumer group.',
                pid_existence: 'Pidfile already exists.'
              }
            }
          )
        end
      end

      optional(:pid).filled(:str?)
      optional(:daemon).filled(:bool?)
      optional(:consumer_groups).filled(:array?)

      validate(consumer_groups_inclusion: :consumer_groups) do |consumer_groups|
        # If there were no consumer_groups declared in the server cli, it means that we will
        # run all of them and no need to validate them here at all
        if consumer_groups.nil?
          true
        else
          (consumer_groups - Karafka::Routing::Builder.instance.map(&:name)).empty?
        end
      end

      validate(pid_existence: :pid) do |pid|
        pid ? !File.exist?(pid) : true
      end
    end
  end
end
