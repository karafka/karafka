# frozen_string_literal: true

# Karafka::Admin.describe_cluster should report the operations the client is authorized to perform
# on the cluster as symbols when requested.

setup_karafka

operations = Karafka::Admin.describe_cluster(include_authorized_operations: true)[
  :authorized_operations
]

assert operations.include?(:describe), operations
assert operations.all?(Symbol), operations
