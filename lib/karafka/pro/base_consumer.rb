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
    # Karafka PRO consumer.
    #
    # If you use PRO, all your consumers should inherit (indirectly) from it.
    #
    # @note In case of using lrj, manual pausing may not be the best idea as resume needs to happen
    #   after each batch is processed.
    class BaseConsumer < Karafka::BaseConsumer
      # Can be used to run preparation code prior to the job being enqueued
      #
      # @private
      # @note This should not be used by the end users as it is part of the lifecycle of things and
      #   not as a part of the public api. This should not perform any extensive operations as it
      #   is blocking and running in the listener thread.
      def on_before_enqueue
        handle_before_enqueue
      rescue StandardError => e
        Karafka.monitor.instrument(
          'error.occurred',
          error: e,
          caller: self,
          type: 'consumer.before_enqueue.error'
        )
      end

      # @private
      # @note This should not be used by the end users as it is part of the lifecycle of things but
      #   not as part of the public api.
      def on_after_consume
        handle_after_consume
      rescue StandardError => e
        Karafka.monitor.instrument(
          'error.occurred',
          error: e,
          caller: self,
          type: 'consumer.after_consume.error'
        )
      end

      # Trigger method for running on partition revocation.
      #
      # @private
      def on_revoked
        handle_revoked

        Karafka.monitor.instrument('consumer.revoked', caller: self) do
          revoked
        end
      rescue StandardError => e
        Karafka.monitor.instrument(
          'error.occurred',
          error: e,
          caller: self,
          type: 'consumer.revoked.error'
        )
      end
    end
  end
end
