# frozen_string_literal: true

module Karafka
  module Admin
    # Namespace for admin operations related to configuration management
    #
    # At the moment Karafka supports configuration management for brokers and topics
    #
    # You can describe configuration as well as alter it.
    #
    # Altering is done in the incremental way.
    module Configs
      extend Helpers::ConfigImporter.new(
        max_wait_time: %i[admin max_wait_time]
      )

      class << self
        # Fetches given resources configurations from Kafka
        #
        # @param resources [Resource, Array<Resource>] single resource we want to describe or
        #   list of resources we are interested in. It is useful to provide multiple resources
        #   when you need data from multiple topics, etc. Karafka will make one query for all the
        #   data instead of doing one per topic.
        #
        # @return [Array<Resource>] array with resources containing their configuration details
        #
        # @note Even if you request one resource, result will always be an array with resources
        #
        # @example Describe topic named "example" and print its config
        #   resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: 'example')
        #   results = Karafka::Admin::Configs.describe(resource)
        #   results.first.configs.each do |config|
        #     puts "#{config.name} - #{config.value}"
        #   end
        def describe(*resources)
          operate_on_resources(
            :describe_configs,
            resources
          )
        end

        # Alters given resources based on the alteration operations accumulated in the provided
        # resources
        #
        # @param resources [Resource, Array<Resource>] single resource we want to alter or
        #   list of resources.
        #
        # @note This operation is not transactional and can work only partially if some config
        #   options are not valid. Always make sure, your alterations are correct.
        #
        # @note We call it `#alter` despite using the Kafka incremental alter API because the
        #   regular alter is deprecated.
        #
        # @example Alter the `delete.retention.ms` and set it to 8640001
        #   resource = Karafka::Admin::Configs::Resource.new(type: :topic, name: 'example')
        #   resource.set('delete.retention.ms', '8640001')
        #   Karafka::Admin::Configs.alter(resource)
        def alter(*resources)
          operate_on_resources(
            :incremental_alter_configs,
            resources
          )
        end

        private

        # @param action [Symbol] runs given action via Rdkafka Admin
        # @param resources [Array<Resource>] resources on which we want to operate
        def operate_on_resources(action, resources)
          resources = Array(resources).flatten

          result = with_admin_wait do |admin|
            admin.public_send(
              action,
              resources.map(&:to_native_hash)
            )
          end

          result.resources.map do |rd_kafka_resource|
            # Create back a resource
            resource = Resource.new(
              name: rd_kafka_resource.name,
              type: rd_kafka_resource.type
            )

            rd_kafka_resource.configs.each do |rd_kafka_config|
              resource.configs << Config.from_rd_kafka(rd_kafka_config)
            end

            resource.configs.sort_by!(&:name)
            resource.configs.freeze

            resource
          end
        end

        # Yields admin instance, allows to run Acl operations and awaits on the final result
        # Makes sure that admin is closed afterwards.
        def with_admin_wait
          Admin.with_admin do |admin|
            yield(admin).wait(max_wait_timeout: max_wait_time)
          end
        end
      end
    end
  end
end
