# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for validating correctness of the server cli command options.
    class ServerCliOptions < Base
      params do
        optional(:consumer_groups).value(:array, :filled?)
      end

      rule(:consumer_groups) do
        # If there were no consumer_groups declared in the server cli, it means that we will
        # run all of them and no need to validate them here at all
        if !value.nil? &&
           !(value - Karafka::App.config.internal.routing.builder.map(&:name)).empty?
          key(:consumer_groups).failure(:consumer_groups_inclusion)
        end
      end
    end
  end
end
