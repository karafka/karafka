# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new(subscription_group_id) }

  let(:partition1) { Rdkafka::Consumer::Partition.new(1, 'topic_name') }
  let(:partition2) { Rdkafka::Consumer::Partition.new(4, 'topic_name') }
  let(:partitions) { { 'topic_name' => [partition1] } }
  let(:subscription_group) { build(:routing_subscription_group) }
  let(:subscription_group_id) { subscription_group.id }
  let(:event) { { subscription_group_id: subscription_group_id, tpl: partitions } }

  describe(
    '#revoked_partitions, #on_rebalance_partitions_revoked, #lost_partitions and #changed?'
  ) do
    it { expect(manager.active?).to eq(false) }

    context 'when there are no revoked partitions' do
      it { expect(manager.revoked_partitions).to eq({}) }
      it { expect(manager.changed?).to eq(false) }
    end

    context 'when some partitions were revoked and not assigned' do
      before { manager.on_rebalance_partitions_revoked(event) }

      it { expect(manager.active?).to eq(true) }

      it 'expect to return them' do
        expect(manager.revoked_partitions).to eq({ 'topic_name' => [partition1.partition] })
      end

      it { expect(manager.changed?).to eq(true) }
    end

    context 'when we clear the manager' do
      before do
        manager.on_rebalance_partitions_revoked(event)
        manager.clear
      end

      it { expect(manager.revoked_partitions).to eq({}) }
      it { expect(manager.changed?).to eq(false) }
    end

    context 'when some of the revoked partitions were assigned back' do
      before do
        manager.on_rebalance_partitions_assigned(
          {
            subscription_group_id: subscription_group_id,
            tpl: { 'topic_name' => [partition1] }
          }
        )
        manager.on_rebalance_partitions_revoked(
          {
            subscription_group_id: subscription_group_id,
            tpl: { 'topic_name' => [partition1, partition2] }
          }
        )
      end

      it { expect(manager.active?).to eq(true) }

      it 'expect not to include them in the lost partitions back' do
        expect(manager.lost_partitions).to eq({ 'topic_name' => [partition2.partition] })
      end

      it 'expect to include them in the revoked partitions back' do
        expected_partitions = [partition1.partition, partition2.partition]
        expect(manager.revoked_partitions).to eq({ 'topic_name' => expected_partitions })
      end

      it { expect(manager.changed?).to eq(true) }
    end

    context 'when rebalance is of a different subscription group' do
      before do
        manager.on_rebalance_partitions_assigned(
          {
            subscription_group_id: SecureRandom.uuid,
            tpl: { 'topic_name' => [partition1] }
          }
        )
        manager.on_rebalance_partitions_revoked(
          {
            subscription_group_id: SecureRandom.uuid,
            tpl: { 'topic_name' => [partition1, partition2] }
          }
        )
      end

      it { expect(manager.active?).to eq(false) }

      it 'expect not to include them in the lost partitions back' do
        expect(manager.lost_partitions).to eq({})
      end

      it 'expect to include them in the revoked partitions back' do
        expect(manager.revoked_partitions).to eq({})
      end

      it { expect(manager.changed?).to eq(false) }
    end
  end

  describe 'events mapping' do
    it { expect(NotificationsChecker.valid?(manager)).to eq(true) }
  end
end
