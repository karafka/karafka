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

          changes = false

          unless topics_to_create.empty?
            changes = true
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
            upscale = {}
            downscale = {}

            topics_to_repartition.each do |topic, partitions|
              from = partitions
              to = topic.declaratives.partitions

              if from < to
                upscale[topic] = partitions
              else
                downscale[topic] = partitions
              end
            end

            unless upscale.empty?
              changes = true
              puts 'Following topics will be repartitioned:'
              puts

              upscale.each do |topic, partitions|
                from = partitions
                to = topic.declaratives.partitions
                y = yellow('~')
                puts "  #{y} #{topic.name}:"
                puts "    #{y} partitions: \"#{red(from)}\" #{grey('=>')} \"#{green(to)}\""
                puts
              end
            end

            unless downscale.empty?
              puts(
                'Following topics repartitioning will be ignored as downscaling is not supported:'
              )
              puts

              downscale.each do |topic, partitions|
                from = partitions
                to = topic.declaratives.partitions

                puts "  #{grey('~')} #{topic.name}:"
                puts "    #{grey('~')} partitions: \"#{grey(from)}\" #{grey('=>')} \"#{grey(to)}\""
                puts
              end
            end
          end

          unless topics_to_alter.empty?
            changes = true
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

          changes
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
              @topics_to_alter[declarative] ||= {}

              @topics_to_alter[declarative][declarative_name] ||= {
                from: '',
                to: declarative_value,
                action: :add
              }

              scoped = @topics_to_alter[declarative][declarative_name]
              # declarative name can be a synonym. In such cases we remap it during the discovery
              # below
              final_name = declarative_name

              topic_c.configs.each do |config|
                names = config.synonyms.map(&:name) << config.name

                next unless names.include?(declarative_name)

                # Always use a non-synonym name if differs
                final_name = config.name
                scoped[:action] = :change
                scoped[:from] = config.value
              end

              # Aligns the name in case synonym was used
              target = @topics_to_alter[declarative].delete(declarative_name)
              @topics_to_alter[declarative][final_name] = target

              # Remove change definitions that would migrate to the same value as present
              @topics_to_alter[declarative].delete_if do |_name, details|
                details[:from] == details[:to]
              end
            end

            # Remove topics without any changes
            @topics_to_alter.delete_if { |_name, configs| configs.empty? }
          end

          @topics_to_alter
        end
      end
    end
  end
end
