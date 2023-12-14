# frozen_string_literal: true

module Karafka
  Acl = Struct.new(
    :resource_type,
    :resource_name,
    :resource_pattern_type,
    :principal,
    :host,
    :operation,
    :permission_type,
  ) do
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
      allow: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_ALLOW,
      deny: Rdkafka::Bindings::RD_KAFKA_ACL_PERMISSION_TYPE_DENY
    }

    class << self
      def create(action)
        with_admin do |admin|
          admin.create_acl(**action.to_h)
        end
      end

      def delete(action)
        with_admin do |admin|
          admin.delete_acl(**action.to_h)
        end
      end

      def describe(action)
        with_admin do |admin|
          admin.describe_acl(**action.to_h)
        end
      end

      private

      def with_admin(&block)
        Admin.with_admin(&block)
      end
    end
  end
end
