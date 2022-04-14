# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  let(:partition1) { Rdkafka::Consumer::Partition.new(1, 'topic_name') }
  let(:partition2) { Rdkafka::Consumer::Partition.new(4, 'topic_name') }
  let(:partitions) { { 'topic_name' => [partition1] } }

  describe '#revoked_partitions and #on_partitions_revoked' do
    context 'when there are no revoked partitions' do
      it { expect(manager.revoked_partitions).to eq({}) }
    end

    context 'when some partitions were revoked and not assigned' do
      before { manager.on_partitions_revoked(nil, partitions) }

      it 'expect to return them' do
        expect(manager.revoked_partitions).to eq({ 'topic_name' => [partition1.partition] })
      end
    end

    context 'when we clear the manager' do
      before do
        manager.on_partitions_revoked(nil, partitions)
        manager.clear
      end

      it { expect(manager.revoked_partitions).to eq({}) }
    end

    context 'when some of the revoked partitions were assigned back' do
      before do
        manager.on_partitions_assigned(nil, { 'topic_name' => [partition1] })
        manager.on_partitions_revoked(nil, { 'topic_name' => [partition1, partition2] })
      end

      it 'expect not to include them in the revoked partitions back' do
        expect(manager.revoked_partitions).to eq({ 'topic_name' => [partition2.partition] })
      end
    end
  end
end
