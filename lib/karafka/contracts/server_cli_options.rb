# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for validating correctness of the server cli command options.
    class ServerCliOptions < Base
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('server_cli_options')
      end

      optional(:consumer_groups) { |cg| cg.is_a?(Array) && !cg.empty? }

      virtual do |data, errors|
        next unless errors.empty?
        next unless data.key?(:consumer_groups)

        value = data.fetch(:consumer_groups)

        # If there were no consumer_groups declared in the server cli, it means that we will
        # run all of them and no need to validate them here at all
        next if value.nil?
        next if (value - Karafka::App.config.internal.routing.builder.map(&:name)).empty?

        [[%i[consumer_groups], :consumer_groups_inclusion]]
      end
    end
  end
end
