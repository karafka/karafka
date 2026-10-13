# frozen_string_literal: true

# Karafka::Admin.describe_cluster should return the cluster id, the controller and the brokers with
# the same ids as the regular cluster metadata, without fetching any topic metadata.

setup_karafka

cluster = Karafka::Admin.describe_cluster
metadata_ids = Karafka::Admin.cluster_info.brokers.map { |broker| broker[:broker_id] }

assert cluster[:cluster_id].is_a?(String), cluster
assert_equal metadata_ids.sort, cluster[:brokers].map { |broker| broker[:id] }.sort
assert metadata_ids.include?(cluster[:controller][:id]), cluster
assert_equal nil, cluster[:authorized_operations]
