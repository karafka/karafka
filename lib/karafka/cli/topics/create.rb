# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Creates topics based on the routing setup and configuration
      class Create < Base
        # @return [Boolean] true if any topic was created, otherwise false
        # @raise [Karafka::Errors::CommandValidationError] when any topic has configuration
        #   unknown to the cluster. Nothing is applied then.
        def call
          ensure_configs_exist_in_cluster!

          any_created = false

          declaratives_routing_topics.each do |topic|
            name = topic.name

            if existing_topics_names.include?(name)
              puts "#{yellow("Skipping")} because topic #{name} already exists."
            else
              supervised("Creating topic #{name}") do
                Admin.create_topic(
                  name,
                  topic.declaratives.partitions,
                  topic.declaratives.replication_factor,
                  topic.declaratives.details
                )
              end

              puts "#{green("Created")} topic #{name}."
              any_created = true
            end
          end

          any_created
        end
      end
    end
  end
end
