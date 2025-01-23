# frozen_string_literal: true

module Karafka
  module Admin
    # Struct and set of operations for ACLs management that simplifies their usage.
    # It allows to use Ruby symbol based definitions instead of usage of librdkafka types
    # (it allows to use rdkafka numerical types as well out of the box)
    #
    # We map the numerical values because they are less descriptive and harder to follow.
    #
    # This API works based on ability to create a `Karafka:Admin::Acl` object that can be then used
    # using `#create`, `#delete` and `#describe` class API.
    class Acl
      extend Helpers::ConfigImporter.new(
        max_wait_time: %i[admin max_wait_time]
      )

      # Types of resources for which we can assign permissions.
      #
      # Resource refers to any entity within the Kafka ecosystem for which access control can be
      # managed using ACLs (Access Control Lists).
      # These resources represent different components of Kafka, such as topics, consumer groups,
      # and the Kafka cluster itself. ACLs can be applied to these resources to control and
      # restrict reading, writing, and administrative operations, ensuring secure and authorized
      # access to Kafka's functionalities.
      RESOURCE_TYPES_MAP = {
        # `:any` is only used for lookups and cannot be used for permission assignments
        any: Rdkafka::Bindings::RD_KAFKA_RESOURCE_ANY,
        # use when you want to assign acl to a given topic
        topic: Rdkafka::Bindings::RD_KAFKA_RESOURCE_TOPIC,
        # use when you want to assign acl to a given consumer group
        consumer_group: Rdkafka::Bindings::RD_KAFKA_RESOURCE_GROUP,
        # use when you want to assign acl to a given broker
        broker: Rdkafka::Bindings::RD_KAFKA_RESOURCE_BROKER
      }.freeze

      # Resource pattern types define how ACLs (Access Control Lists) are applied to resources,
      # specifying the scope and applicability of access rules.
      # They determine whether an ACL should apply to a specific named resource, a prefixed group
      # of resources, or all resources of a particular type.
      RESOURCE_PATTERNS_TYPE_MAP = {
        # `:any` is only used for lookups and cannot be used for permission assignments
        any: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_ANY,
        # Targets resources with a pattern matching for broader control with a single rule.
        match: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_MATCH,
        # Targets a specific named resource, applying ACLs directly to that resource.
        literal: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_LITERAL,
        # Applies ACLs to all resources with a common name prefix, enabling broader control with a
        # single rule.
        prefixed: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_PREFIXED
      }.freeze

      # ACL operations define the actions that can be performed on Kafka resources. Each operation
      # represents a specific type of access or action that can be allowed or denied.
      OPERATIONS_MAP = {
        # `:any` is only used for lookups
        any: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ANY,
        # Grants complete access to a resource, encompassing all possible operations,
        # typically used for unrestricted control.
        all: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ALL,
        # Grants the ability to read data from a topic or a consumer group.
        read: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_READ,
        # Allows for writing data on a topic.
        write: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_WRITE,
        # Permits the creation of topics or consumer groups.
        create: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_CREATE,
        #  Enables the deletion of topics.
        delete: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_DELETE,
        # Allows modification of topics or consumer groups.
        alter: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ALTER,
        # Grants the ability to view metadata and configurations of topics or consumer groups.
        describe: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_DESCRIBE,
        # Permits actions that apply to the Kafka cluster, like broker management.
        cluster_action: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_CLUSTER_ACTION,
        # Allows viewing configurations for resources like topics and brokers.
        describe_configs: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_DESCRIBE_CONFIGS,
        # Enables modification of configurations for resources.
        alter_configs: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ALTER_CONFIGS,
        # Grants the ability to perform idempotent writes, ensuring exactly-once semantics in
        # message production.
        idempotent_write: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_IDEMPOTENT_WRITE
      }.freeze

      # ACL permission types specify the nature of the access control applied to Kafka resources.
      # These types are used to either grant or deny specified operations.
      PERMISSION_TYPES_MAP = {
        # Used for lookups, indicating no specific permission type.
        any: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_ANY,
        # Grants the specified operations, enabling the associated actions on the resource.
        allow: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_ALLOW,
        # Blocks the specified operations, preventing the associated actions on the resource.
        deny: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_DENY
      }.freeze

      # Array with all maps used for the Acls support
      ALL_MAPS = [
        RESOURCE_TYPES_MAP,
        RESOURCE_PATTERNS_TYPE_MAP,
        OPERATIONS_MAP,
        PERMISSION_TYPES_MAP
      ].freeze

      private_constant :RESOURCE_TYPES_MAP, :RESOURCE_PATTERNS_TYPE_MAP, :OPERATIONS_MAP,
                       :PERMISSION_TYPES_MAP, :ALL_MAPS

      # Class level APIs that operate on Acl instances and/or return Acl instances.
      # @note For the sake of consistency all methods from this API return array of Acls
      class << self
        # Creates (unless already present) a given ACL rule in Kafka
        # @param acl [Acl]
        # @return [Array<Acl>] created acls
        def create(acl)
          with_admin_wait do |admin|
            admin.create_acl(**acl.to_native_hash)
          end

          [acl]
        end

        # Removes acls matching provide acl pattern.
        # @param acl [Acl]
        # @return [Array<Acl>] deleted acls
        # @note More than one Acl may be removed if rules match that way
        def delete(acl)
          result = with_admin_wait do |admin|
            admin.delete_acl(**acl.to_native_hash)
          end

          result.deleted_acls.map do |result_acl|
            from_rdkafka(result_acl)
          end
        end

        # Takes an Acl definition and describes all existing Acls matching its criteria
        # @param acl [Acl]
        # @return [Array<Acl>] described acls
        def describe(acl)
          result = with_admin_wait do |admin|
            admin.describe_acl(**acl.to_native_hash)
          end

          result.acls.map do |result_acl|
            from_rdkafka(result_acl)
          end
        end

        # Returns all acls on a cluster level
        # @return [Array<Acl>] all acls
        def all
          describe(
            new(
              resource_type: :any,
              resource_name: nil,
              resource_pattern_type: :any,
              principal: nil,
              operation: :any,
              permission_type: :any,
              host: '*'
            )
          )
        end

        private

        # Yields admin instance, allows to run Acl operations and awaits on the final result
        # Makes sure that admin is closed afterwards.
        def with_admin_wait
          Admin.with_admin do |admin|
            yield(admin).wait(max_wait_timeout: max_wait_time)
          end
        end

        # Takes a rdkafka Acl result and converts it into our local Acl representation. Since the
        # rdkafka Acl object is an integer based on on types, etc we remap it into our "more" Ruby
        # form.
        #
        # @param rdkafka_acl [Rdkafka::Admin::AclBindingResult]
        # return [Acl] mapped acl
        def from_rdkafka(rdkafka_acl)
          new(
            resource_type: rdkafka_acl.matching_acl_resource_type,
            resource_name: rdkafka_acl.matching_acl_resource_name,
            resource_pattern_type: rdkafka_acl.matching_acl_pattern_type,
            principal: rdkafka_acl.matching_acl_principal,
            host: rdkafka_acl.matching_acl_host,
            operation: rdkafka_acl.matching_acl_operation,
            permission_type: rdkafka_acl.matching_acl_permission_type
          )
        end
      end

      attr_reader :resource_type, :resource_name, :resource_pattern_type, :principal, :host,
                  :operation, :permission_type

      # Initializes a new Acl instance with specified attributes.
      #
      # @param resource_type [Symbol, Integer] Specifies the type of Kafka resource
      #   (like :topic, :consumer_group).
      #   Accepts either a symbol from RESOURCE_TYPES_MAP or a direct rdkafka numerical type.
      # @param resource_name [String, nil] The name of the Kafka resource
      #   (like a specific topic name). Can be nil for certain types of resource pattern types.
      # @param resource_pattern_type [Symbol, Integer] Determines how the ACL is applied to the
      #   resource. Uses a symbol from RESOURCE_PATTERNS_TYPE_MAP or a direct rdkafka numerical
      #   type.
      # @param principal [String, nil] Specifies the principal (user or client) for which the ACL
      #   is being defined. Can be nil if not applicable.
      # @param host [String] (default: '*') Defines the host from which the principal can access
      #   the resource. Defaults to '*' for all hosts.
      # @param operation [Symbol, Integer] Indicates the operation type allowed or denied by the
      #   ACL. Uses a symbol from OPERATIONS_MAP or a direct rdkafka numerical type.
      # @param permission_type [Symbol, Integer] Specifies whether to allow or deny the specified
      #   operation. Uses a symbol from PERMISSION_TYPES_MAP or a direct rdkafka numerical type.
      #
      # Each parameter is mapped to its corresponding value in the respective *_MAP constant,
      # allowing usage of more descriptive Ruby symbols instead of numerical types.
      def initialize(
        resource_type:,
        resource_name:,
        resource_pattern_type:,
        principal:,
        host: '*',
        operation:,
        permission_type:
      )
        @resource_type = map(resource_type, RESOURCE_TYPES_MAP)
        @resource_name = resource_name
        @resource_pattern_type = map(resource_pattern_type, RESOURCE_PATTERNS_TYPE_MAP)
        @principal = principal
        @host = host
        @operation = map(operation, OPERATIONS_MAP)
        @permission_type = map(permission_type, PERMISSION_TYPES_MAP)
        freeze
      end

      # Converts the Acl into a hash with native rdkafka types
      # @return [Hash] hash with attributes matching rdkafka numerical types
      def to_native_hash
        {
          resource_type: remap(resource_type, RESOURCE_TYPES_MAP),
          resource_name: resource_name,
          resource_pattern_type: remap(resource_pattern_type, RESOURCE_PATTERNS_TYPE_MAP),
          principal: principal,
          host: host,
          operation: remap(operation, OPERATIONS_MAP),
          permission_type: remap(permission_type, PERMISSION_TYPES_MAP)
        }.freeze
      end

      private

      # Maps the provided attribute based on the mapping hash and if not found returns the
      # attribute itself. Useful when converting from Acl symbol based representation to the
      # rdkafka one.
      #
      # @param value [Symbol, Integer] The value to be mapped.
      # @param mappings [Hash] The hash containing the mapping data.
      # @return [Integer, Symbol] The mapped value or the original value if not found in mappings.
      def map(value, mappings)
        validate_attribute!(value)

        mappings.invert.fetch(value, value)
      end

      # Remaps the provided attribute based on the mapping hash and if not found returns the
      # attribute itself. Useful when converting from Acl symbol based representation to the
      # rdkafka one.
      #
      # @param value [Symbol, Integer] The value to be mapped.
      # @param mappings [Hash] The hash containing the mapping data.
      # @return [Integer, Symbol] The mapped value or the original value if not found in mappings.
      def remap(value, mappings)
        validate_attribute!(value)

        mappings.fetch(value, value)
      end

      # Validates that the attribute exists in any of the ACL mappings.
      # Raises an error if the attribute is not supported.
      # @param attribute [Symbol, Integer] The attribute to be validated.
      # @raise [Karafka::Errors::UnsupportedCaseError] raised if attribute not found
      def validate_attribute!(attribute)
        ALL_MAPS.each do |mappings|
          return if mappings.keys.any?(attribute)
          return if mappings.values.any?(attribute)
        end

        raise Karafka::Errors::UnsupportedCaseError, attribute
      end
    end
  end
end
