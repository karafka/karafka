# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Increases number of partitions on topics that have less partitions than defined
      # Will **not** create topics if missing.
      class Repartition < Base
        # @return [Boolean] true if anything was repartitioned, otherwise false
        def call
          any_repartitioned = false

          existing_partitions = existing_topics.map do |topic|
            [topic.fetch(:topic_name), topic.fetch(:partition_count)]
          end.to_h

          declaratives_routing_topics.each do |topic|
            name = topic.name

            desired_count = topic.config.partitions
            existing_count = existing_partitions.fetch(name, false)

            if existing_count && existing_count < desired_count
              puts "Increasing number of partitions to #{desired_count} on topic #{name}..."
              Admin.create_partitions(name, desired_count)
              change = desired_count - existing_count
              puts "#{green('Created')} #{change} additional partitions on topic #{name}."
              any_repartitioned = true
            elsif existing_count
              puts "#{yellow('Skipping')} because topic #{name} has #{existing_count} partitions."
            else
              puts "#{yellow('Skipping')} because topic #{name} does not exist."
            end
          end

          any_repartitioned
        end
      end
    end
  end
end
