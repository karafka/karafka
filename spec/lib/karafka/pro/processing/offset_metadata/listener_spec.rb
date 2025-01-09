# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:fetcher) { Karafka::Pro::Processing::OffsetMetadata::Fetcher.instance }
  let(:subscription_group) { rand.to_s }
  let(:client) { rand }
  let(:event) { { subscription_group: subscription_group, client: client } }

  describe '#on_connection_listener_before_fetch_loop' do
    before { allow(fetcher).to receive(:register) }

    it 'expect to register client' do
      listener.on_connection_listener_before_fetch_loop(event)

      expect(fetcher).to have_received(:register).with(client)
    end
  end

  describe '#on_rebalance_partitions_assigned' do
    before { allow(fetcher).to receive(:clear) }

    it 'expect to clear fetcher subscription group' do
      listener.on_rebalance_partitions_assigned(event)

      expect(fetcher).to have_received(:clear).with(subscription_group)
    end
  end

  describe '#on_rebalance_partitions_revoked' do
    before { allow(fetcher).to receive(:clear) }

    it 'expect to clear fetcher subscription group' do
      listener.on_rebalance_partitions_revoked(event)

      expect(fetcher).to have_received(:clear).with(subscription_group)
    end
  end
end
