# frozen_string_literal: true

module Karafka
  module Admin
    class Acl < Struct.new(
:resource_type,
:resource_name,
:resource_pattern_type,
:principal,
:host,
:operation,
:permission_type,
  keyword_init: true
)
      RESOURCE_TYPES_MAP = {
        any: Rdkafka::Bindings::RD_KAFKA_RESOURCE_ANY,
        topic: Rdkafka::Bindings::RD_KAFKA_RESOURCE_TOPIC,
        consumer_group: Rdkafka::Bindings::RD_KAFKA_RESOURCE_GROUP
        # Enable once fix is released
        #  broker: Rdkafka::Bindings::RD_KAFKA_RESOURCE_BROKER
      }

      RESOURCE_PATTERNS_TYPE_MAP = {
        any: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_ANY,
        match: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_MATCH,
        literal: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_LITERAL,
        prefixed: Rdkafka::Bindings::RD_KAFKA_RESOURCE_PATTERN_PREFIXED,
      }

      OPERATIONS_MAP = {
        any: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ANY,
        all: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ALL,
        read: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_READ,
        write: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_WRITE,
        create: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_CREATE,
        delete: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_DELETE,
        alter: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ALTER,
        describe: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_DESCRIBE,
        cluster_action: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_CLUSTER_ACTION,
        describe_configs: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_DESCRIBE_CONFIGS,
        alter_configs: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_ALTER_CONFIGS,
        idempotent_write: Rdkafka::Bindings::RD_KAFKA_ACL_OPERATION_IDEMPOTENT_WRITE
      }

      PERMISSION_TYPES_MAP = {
        any: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_ANY,
        allow: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_ALLOW,
        deny: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_DENY
      }

      private_constant :RESOURCE_TYPES_MAP, :RESOURCE_PATTERNS_TYPE_MAP, :OPERATIONS_MAP,
                       :PERMISSION_TYPES_MAP

      class << self
        def create(action)
          with_admin_wait do |admin|
            admin.create_acl(**action.to_native)
          end

          [action]
        end

        def delete(action)
          result = with_admin_wait do |admin|
            admin.delete_acl(**action.to_native)
          end

          result.deleted_acls.map do |acl|
            convert(acl)
          end
        end

        def describe(action)
          result = with_admin_wait do |admin|
            admin.describe_acl(**action.to_native)
          end

          result.acls
        end

        private

        def with_admin_wait
          Admin.with_admin do |admin|
            yield(admin).wait(max_wait_timeout: Karafka::App.config.admin.max_wait_time)
          end
        end

        def convert(rdkafka_acl)
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

      def initialize(
        resource_type:,
        resource_name:,
        resource_pattern_type:,
        principal:,
        host: '*',
        operation:,
        permission_type:
      )
        super()
        self.resource_type = remap(resource_type, RESOURCE_TYPES_MAP)
        self.resource_name = resource_name
        self.resource_pattern_type = remap(resource_pattern_type, RESOURCE_PATTERNS_TYPE_MAP)
        self.principal = principal
        self.host = host
        self.operation = remap(operation, OPERATIONS_MAP)
        self.permission_type = remap(permission_type, PERMISSION_TYPES_MAP)
        freeze
      end

      def to_native
        {
          resource_type: remap(resource_type, RESOURCE_TYPES_MAP),
          resource_name: resource_name,
          resource_pattern_type: remap(resource_pattern_type, RESOURCE_PATTERNS_TYPE_MAP),
          principal: principal,
          host: host,
          operation: remap(operation, OPERATIONS_MAP),
          permission_type: remap(permission_type, PERMISSION_TYPES_MAP),
        }.freeze
      end

      private

      def map(value, mappings)
        mappings.fetch(value, value)
      end

      def remap(value, mappings)
        mappings.invert.fetch(value, value)
      end
    end
  end
end
