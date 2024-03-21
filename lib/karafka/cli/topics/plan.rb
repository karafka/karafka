# frozen_string_literal: true

module Karafka
  class Cli
    class Topics < Cli::Base
      # Plans the migration process and prints what changes are going to be applied if migration
      # would to be executed
      class Plan < Base
        # Figures out scope of changes that need to happen
        # @return [Boolean] true if running migrate would change anything, false otherwise
        def call
          # If no changes at all, just print and stop
          if topics_to_create.empty? && topics_to_repartition.empty? && topics_to_alter.empty?
            puts "Karafka will #{yellow('not')} perform any actions. No changes needed."

            return false
          end

          unless topics_to_create.empty?
            puts 'Following topics will be created:'
            puts

            topics_to_create.each do |topic|
              puts "  #{green('+')} #{topic.name}:"
              puts "    #{green('+')} partitions: \"#{topic.declaratives.partitions}\""

              topic.declaratives.details.each do |name, value|
                puts "    #{green('+')} #{name}: \"#{value}\""
              end

              puts
            end
          end

          unless topics_to_repartition.empty?
            puts 'Following topics will be repartitioned:'
            puts

            topics_to_repartition.each do |topic, partitions|
              from = partitions
              to = topic.declaratives.partitions

              puts "  #{yellow('~')} #{topic.name}:"
              puts "    #{yellow('~')} partitions: \"#{red(from)}\" #{grey('=>')} \"#{green(to)}\""
              puts
            end
          end

          unless topics_to_alter.empty?
            puts 'Following topics will have configuration changes:'
            puts

            topics_to_alter.each do |topic, configs|
              puts "  #{yellow('~')} #{topic.name}:"

              configs.each do |name, changes|
                from = changes.fetch(:from)
                to = changes.fetch(:to)
                action = changes.fetch(:action)
                type = action == :change ? yellow('~') : green('+')
                puts "    #{type} #{name}: \"#{red(from)}\" #{grey('=>')} \"#{green(to)}\""
              end

              puts
            end
          end

          true
        end

        private

        # @return [Array<Karafka::Routing::Topic>] topics that will be created
        def topics_to_create
          return @topics_to_create if @topics_to_create

          @topics_to_create = declaratives_routing_topics.reject do |topic|
            existing_topics_names.include?(topic.name)
          end

          @topics_to_create
        end

        # @return [Array<Array<Karafka::Routing::Topic, Integer>>] array with topics that will
        #   be repartitioned and current number of partitions
        def topics_to_repartition
          return @topics_to_repartition if @topics_to_repartition

          @topics_to_repartition = []

          declaratives_routing_topics.each do |declarative_topic|
            existing_topic = existing_topics.find do |topic|
              topic.fetch(:topic_name) == declarative_topic.name
            end

            next unless existing_topic

            existing_partitions = existing_topic.fetch(:partition_count)

            next if declarative_topic.declaratives.partitions == existing_partitions

            @topics_to_repartition << [declarative_topic, existing_partitions]
          end

          @topics_to_repartition
        end

        # @return [Hash] Hash where keys are topics to alter and values are configs that will
        #   be altered.
        def topics_to_alter
          return @topics_to_alter if @topics_to_alter

          topics_to_check = []

          declaratives_routing_topics.each do |declarative_topic|
            next if declarative_topic.declaratives.details.empty?
            next unless existing_topics_names.include?(declarative_topic.name)

            topics_to_check << [
              declarative_topic,
              Admin::Configs::Resource.new(type: :topic, name: declarative_topic.name)
            ]
          end

          @topics_to_alter = {}

          return @topics_to_alter if topics_to_check.empty?

          Admin::Configs.describe(topics_to_check.map(&:last)).each.with_index do |topic_c, index|
            declarative = topics_to_check[index].first
            declarative_config = declarative.declaratives.details.dup
            declarative_config.transform_keys!(&:to_s)
            declarative_config.transform_values!(&:to_s)

            # We only apply additive/in-place changes so we start from our config
            declarative_config.each do |declarative_name, declarative_value|
              topic_c.configs.each do |config|
                next unless declarative_name == config.name

                @topics_to_alter[declarative] ||= {}
                @topics_to_alter[declarative][declarative_name] = {
                  from: config.value,
                  to: declarative_value,
                  action: :change
                }
              end

              @topics_to_alter[declarative][declarative_name] ||= {
                from: '',
                to: declarative_value,
                action: :add
              }
            end
          end

          @topics_to_alter
        end
      end
    end
  end
end
