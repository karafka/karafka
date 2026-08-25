# frozen_string_literal: true

module Karafka
  class Cli
    # CLI related contracts
    module Contracts
      # Contract for validating correctness of the server cli command options.
      class Server < Karafka::Contracts::Base
        configure do |config|
          config.error_messages = YAML.safe_load_file(
            File.join(Karafka.gem_root, "config", "locales", "errors.yml")
          ).fetch("en").fetch("validations").fetch("cli").fetch("server")
        end

        %i[
          include
          exclude
        ].each do |action|
          optional(:"#{action}_consumer_groups") { |val| val.is_a?(Array) }
          optional(:"#{action}_subscription_groups") { |sg| sg.is_a?(Array) }
          optional(:"#{action}_topics") { |topics| topics.is_a?(Array) }

          virtual do |data, errors|
            next unless errors.empty?

            value = data.fetch(:"#{action}_consumer_groups")

            # If there were no consumer_groups declared in the server cli, it means that we will
            # run all of them and no need to validate them here at all
            next if value.empty?
            # Wildcard patterns are not validated against the current routing because they may
            # match consumer groups that do not exist yet
            next if (literal(value) - Karafka::App.routes.map(&:name)).empty?

            # Found unknown consumer groups
            [[[:"#{action}_consumer_groups"], :consumer_groups_inclusion]]
          end

          virtual do |data, errors|
            next unless errors.empty?

            value = data.fetch(:"#{action}_subscription_groups")

            # If there were no subscription_groups declared in the server cli, it means that we
            # will run all of them and no need to validate them here at all
            next if value.empty?

            subscription_groups = Karafka::App
              .routes
              .map(&:subscription_groups)
              .flatten
              .map(&:name)

            # Wildcard patterns are not validated against the current routing because they may
            # match subscription groups that do not exist yet
            next if (literal(value) - subscription_groups).empty?

            # Found unknown subscription groups
            [[[:"#{action}_subscription_groups"], :subscription_groups_inclusion]]
          end

          virtual do |data, errors|
            next unless errors.empty?

            value = data.fetch(:"#{action}_topics")

            # If there were no topics declared in the server cli, it means that we will
            # run all of them and no need to validate them here at all
            next if value.empty?

            topics = Karafka::App
              .routes
              .map(&:subscription_groups)
              .flatten
              .map(&:topics)
              .map { |gtopics| gtopics.map(&:name) }
              .flatten

            # Wildcard patterns are not validated against the current routing because they may
            # match topics that do not exist yet
            next if (literal(value) - topics).empty?

            # Found unknown topics
            [[[:"#{action}_topics"], :topics_inclusion]]
          end
        end

        # Makes sure we have anything to subscribe to when we start the server
        virtual do |_, errors|
          next unless errors.empty?

          next unless Karafka::App.subscription_groups.empty?

          [[%i[include_topics], :topics_missing]]
        end

        class << self
          # @param values [Array<String>] include/exclude cli values
          # @return [Array<String>] only the literal (non wildcard) values, so wildcard patterns
          #   are not checked against the current routing state
          def literal(values)
            values.reject { |value| Karafka::Routing::ActivityManager.wildcard?(value) }
          end
        end
      end
    end
  end
end
