# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:manager) { Karafka::App.config.internal.connection.manager }
  let(:consumer_group_id) { SecureRandom.uuid }
  let(:event) { { consumer_group_id: consumer_group_id } }

  before { allow(manager).to receive(:notice) }

  describe '#on_rebalance_partitions_assigned' do
    it 'expect to be noticed' do
      listener.on_rebalance_partitions_assigned(event)

      expect(manager).to have_received(:notice).with(consumer_group_id)
    end
  end

  describe '#on_rebalance_partitions_revoked' do
    it 'expect to be noticed' do
      listener.on_rebalance_partitions_assigned(event)

      expect(manager).to have_received(:notice).with(consumer_group_id)
    end
  end
end
