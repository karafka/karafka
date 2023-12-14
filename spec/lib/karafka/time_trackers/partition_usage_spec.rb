# frozen_string_literal: true

RSpec.describe_current do
  let(:partition_usage) { described_class.new }
  let(:topic) { 'test_topic' }
  let(:partition) { 1 }
  let(:interval) { 1_000 }

  describe '#active?' do
    context 'when a partition has been used recently' do
      it 'returns true' do
        partition_usage.track(topic, partition)
        sleep(0.5)
        expect(partition_usage.active?(topic, partition, interval)).to be true
      end
    end

    context 'when a partition has not been used within the recent time' do
      it 'returns false' do
        partition_usage.track(topic, partition)
        sleep(1.1)
        expect(partition_usage.active?(topic, partition, interval)).to be false
      end
    end
  end

  describe '#track' do
    it 'marks a partition as active' do
      partition_usage.track(topic, partition)
      expect(partition_usage.active?(topic, partition, interval)).to be true
    end
  end

  describe '#revoke' do
    before { partition_usage.track(topic, partition) }

    it 'removes the reference to the given partition' do
      partition_usage.revoke(topic, partition)
      expect(partition_usage.active?(topic, partition, interval)).to be false
    end
  end
end
