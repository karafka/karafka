# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Offset Metadata support on the processing side
      module OffsetMetadata
        # This fetcher is responsible for fetching and caching committed offsets metadata
        # information.
        #
        # By design we fetch all information for a requested topic assignments. Not all topics from
        # the same subscription group may need metadata and even if, we can run the few smaller
        # queries. This approach prevents us from querying all assigned topics data in one go
        # preventing excessive queries.
        #
        # Since the assumption is, that user will not have to reach out for the later metadata
        # since it is produced in the context of a given consumer assignment, we can cache the
        # initial result and only allow users for explicit invalidation.
        class Fetcher
          include Singleton

          class << self
            extend Forwardable

            def_delegators :instance, :register, :clear, :find
          end

          def initialize
            @mutexes = {}
            @clients = {}
            @tpls = {}
          end

          # Registers a client of a given subscription group, so we can use it for queries later on
          # @param client [Karafka::Connection::Client]
          # @note Since we store the client reference and not the underlying rdkafka consumer
          #   instance, we do not have to deal with the recovery as it is abstracted away
          def register(client)
            @clients[client.subscription_group] = client
            # We use one mutex per SG because independent SGs can query in parallel
            @mutexes[client.subscription_group] = Mutex.new
            @tpls[client.subscription_group] = {}
          end

          # Queries or retrieves from cache the given offset metadata for the selected partition
          #
          # @param topic [Karafka::Routing::Topic] routing topic with subscription group reference
          # @param partition [Integer] partition for which we want to get stored offset metadata
          # @param cache [Boolean] forces explicit query to Kafka when false and cache refresh.
          #   By default we use the setting from the topic level but this can be overwritten on
          #   a per request basis if needed.
          # @return [Object, false] deserialized metadata (string deserializer by default) or
          #   false in case we were not able to obtain the details because we have lost the
          #   assignment
          def find(topic, partition, cache: true)
            cache = topic.offset_metadata.cache? && cache

            tpls = fetch(topic, cache)

            return false unless tpls

            t_partitions = tpls.fetch(topic.name, [])
            t_partition = t_partitions.find { |t_p| t_p.partition == partition }

            # If we do not have given topic partition here, it means it is no longer part of our
            # assignment and we should return false
            return false unless t_partition

            topic.offset_metadata.deserializer.call(t_partition.metadata)
          end

          # Clears cache of a given subscription group. It is triggered on assignment changes.
          #
          # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group that
          #   we want to clear.
          def clear(subscription_group)
            @mutexes.fetch(subscription_group).synchronize do
              @tpls[subscription_group].clear
            end
          end

          private

          # Fetches from Kafka all committed offsets for the given topic partitions that are
          # assigned to this process.
          #
          # We fetch all because in majority of the cases, the behavior of the end user code is
          #   not specific to a given partition both same for all. In such cases we save on
          #   querying as we get all data for all partitions in one go.
          #
          # @param topic [Karafka::Routing::Topic] topic for which we want to fetch tpls data
          # @param cache [Boolean] should we return cached data if present
          def fetch(topic, cache)
            subscription_group = topic.subscription_group
            t_tpls = @tpls.fetch(subscription_group, false)
            t_tpl = t_tpls[topic]

            return t_tpl if t_tpl && cache

            assigned_tpls = @clients.fetch(subscription_group).assignment
            t_tpl = assigned_tpls.to_h.fetch(topic.name, false)

            # May be false in case we lost given assignment but still run LRJ
            return false unless t_tpl
            return false if t_tpl.empty?

            @mutexes.fetch(subscription_group).synchronize do
              rd_tpl = Rdkafka::Consumer::TopicPartitionList.new(topic.name => t_tpl)

              # While in theory we could lost assignment while being here, this will work and will
              # return us proper tpl, we do not deal with this case on this layer and report anyhow
              # There will not be any exception and this will operate correctly
              t_tpls[topic] = @clients.fetch(subscription_group).committed(rd_tpl).to_h
            end
          end
        end
      end
    end
  end
end
