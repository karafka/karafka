# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for validating correctness of the server cli command options
    # We validate some basics + the list of consumer_groups on which we want to use, to make
    # sure that all of them are defined, plus that a pidfile does not exist
    class ServerCliOptions < Dry::Validation::Contract
      params do
        optional(:pid).filled(:str?)
        optional(:daemon).filled(:bool?)
        optional(:consumer_groups).value(:array, :filled?)
      end

      rule(:pid) do
        key(:pid).failure(:pid_already_exists) if value && File.exist?(value)
      end

      rule(:consumer_groups) do
        # If there were no consumer_groups declared in the server cli, it means that we will
        # run all of them and no need to validate them here at all
        if !value.nil? &&
           !(value - Karafka::Routing::Builder.instance.map(&:name)).empty?
          key(:consumer_groups).failure(:consumer_groups_inclusion)
        end
      end
    end
  end
end
