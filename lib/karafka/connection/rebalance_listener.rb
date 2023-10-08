# frozen_string_literal: true

module Karafka
  module Connection
    class RebalanceListener
      def initialize(subscription_group)
        @subscription_group = subscription_group
      end

      def partitions_revoke(code, tpl)
        instrument('partitions_revoke', tpl)
      end

      def partitions_assign(tpl)
        instrument('partitions_assign', tpl)
      end

      def partitions_revoked(tpl)
        instrument('partitions_revoked', tpl)
      end

      def partitions_assigned(tpl)
        instrument('partitions_assigned', tpl)
      end

      private

      def instrument(name, tpl)
        ::Karafka.monitor.instrument(
          "connection.client.rebalance_manager.#{name}",
          caller: self,
          subscription_group: @subscription_group,
          tpl: tpl
        )
      end
    end
  end
end
