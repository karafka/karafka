# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Processing
      module OffsetMetadata
        # Keeps track of rebalances and updates the fetcher
        # Since we cache the tpls with metadata, we need to invalidate them on events that would
        # cause changes in the assignments
        class Listener
          # When we start listening we need to register this client in the metadata fetcher, so
          # we have the client related to a given subscription group that we can use in fetcher
          # since fetcher may be used in filtering API and other places outside of the standard
          # consumer flow
          # @param event [Karafka::Core::Monitoring::Event]
          def on_connection_listener_before_fetch_loop(event)
            Fetcher.register event[:client]
          end

          # Invalidates internal cache when assignments change so we can get correct metadata
          # @param event [Karafka::Core::Monitoring::Event]
          def on_rebalance_partitions_assigned(event)
            Fetcher.clear event[:subscription_group]
          end

          # Invalidates internal cache when assignments change so we can get correct metadata
          # @param event [Karafka::Core::Monitoring::Event]
          def on_rebalance_partitions_revoked(event)
            Fetcher.clear event[:subscription_group]
          end
        end
      end
    end
  end
end
