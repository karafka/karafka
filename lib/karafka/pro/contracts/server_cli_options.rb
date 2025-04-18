# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Contracts
      # Contract for validating correctness of the server cli command options.
      # It differs slightly from the OSS one because it is aware of the routing patterns
      class ServerCliOptions < ::Karafka::Contracts::ServerCliOptions
        configure do |config|
          config.error_messages = YAML.safe_load(
            File.read(
              File.join(Karafka.gem_root, 'config', 'locales', 'errors.yml')
            )
          ).fetch('en').fetch('validations').fetch('server_cli_options')
        end

        %i[
          include
          exclude
        ].each do |action|
          optional(:"#{action}_consumer_groups") { |cg| cg.is_a?(Array) }
          optional(:"#{action}_subscription_groups") { |sg| sg.is_a?(Array) }
          optional(:"#{action}_topics") { |topics| topics.is_a?(Array) }

          virtual do |data, errors|
            next unless errors.empty?

            value = data.fetch(:"#{action}_consumer_groups")

            # If there were no consumer_groups declared in the server cli, it means that we will
            # run all of them and no need to validate them here at all
            next if value.empty?
            next if (value - Karafka::App.consumer_groups.map(&:name)).empty?

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
                                  .consumer_groups
                                  .map(&:subscription_groups)
                                  .flatten
                                  .map(&:name)

            next if (value - subscription_groups).empty?

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
                     .consumer_groups
                     .map(&:subscription_groups)
                     .flatten
                     .map(&:topics)
                     .map { |gtopics| gtopics.map(&:name) }
                     .flatten

            next if (value - topics).empty?

            # If there are any patterns defined, we cannot report on topics inclusions because
            # topics may be added during boot or runtime. We go with simple assumption:
            # if there are patterns defined, we do not check the inclusions at all
            next unless Karafka::App.consumer_groups.map(&:patterns).flatten.empty?

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
      end
    end
  end
end
