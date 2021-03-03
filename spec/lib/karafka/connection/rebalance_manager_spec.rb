# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  let(:partition) { Rdkafka::Consumer::Partition.new(rand(0..100), 'topic_name') }
  let(:partitions) { { 'topic_name' => [partition] } }

  describe '#assigned_partitions and #on_partitions_assigned' do
    context 'when there are no assigned partitions' do
      it { expect(manager.assigned_partitions).to eq({}) }
    end

    context 'when some partitions are assigned' do
      before { manager.on_partitions_assigned(nil, partitions) }

      it 'expect to clear the assigment after returning it' do
        expect(manager.assigned_partitions).to eq({ 'topic_name' => [partition.partition] })
        expect(manager.assigned_partitions).to eq({})
      end
    end
  end

  describe '#revoked_partitions and #on_partitions_revoked' do
    context 'when there are no revoked partitions' do
      it { expect(manager.revoked_partitions).to eq({}) }
    end

    context 'when some partitions are revoked' do
      before { manager.on_partitions_revoked(nil, partitions) }

      it 'expect to clear the assigment after returning it' do
        expect(manager.revoked_partitions).to eq({ 'topic_name' => [partition.partition] })
        expect(manager.revoked_partitions).to eq({})
      end
    end
  end
end
