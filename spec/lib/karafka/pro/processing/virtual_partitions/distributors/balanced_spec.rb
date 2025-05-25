# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:config) do
    instance_double(
      Karafka::Pro::Routing::Features::VirtualPartitions::Config,
      partitioner: partitioner,
      reducer: reducer,
      max_partitions: max_partitions
    )
  end

  let(:partitioner) { ->(msg) { msg.raw_key } }
  let(:reducer) { ->(key) { key % 3 } }
  let(:max_partitions) { 3 }

  subject(:distributor) { described_class.new(config) }

  describe '#call' do
    let(:messages) do
      [
        build(:messages_message, raw_key: 'a', offset: 1),
        build(:messages_message, raw_key: 'a', offset: 2),
        build(:messages_message, raw_key: 'a', offset: 4),
        build(:messages_message, raw_key: 'b', offset: 5),
        build(:messages_message, raw_key: 'b', offset: 6),
        build(:messages_message, raw_key: 'c', offset: 7),
        build(:messages_message, raw_key: 'a', offset: 3)
      ]
    end

    it 'distributes messages across workers based on load' do
      result = distributor.call(messages)

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([0, 1, 2])
      expect(result[0].size).to eq(4)
      expect(result[1].size).to eq(2)
      expect(result[2].size).to eq(1)
    end

    it 'sorts messages within each group by offset' do
      result = distributor.call(messages)

      expect(result[0].map(&:offset)).to eq([1, 2, 3, 4])
      expect(result[1].map(&:offset)).to eq([5, 6])
    end

    context 'when there are fewer messages than max_partitions' do
      let(:max_partitions) { 2 }

      it 'only creates necessary workers' do
        result = distributor.call(messages)
        expect(result.keys).to eq([0, 1])
      end
    end

    context 'when there are more groups than max_partitions' do
      let(:messages) do
        [
          build(:messages_message, raw_key: 'a', offset: 1),
          build(:messages_message, raw_key: 'a', offset: 2),
          build(:messages_message, raw_key: 'b', offset: 3),
          build(:messages_message, raw_key: 'c', offset: 4),
          build(:messages_message, raw_key: 'd', offset: 5),
          build(:messages_message, raw_key: 'e', offset: 6)
        ]
      end

      it 'distributes groups across available workers' do
        result = distributor.call(messages)

        expect(result.keys).to eq([0, 1, 2])
        expect(result.values.map(&:size)).to eq([2, 2, 2])
      end
    end
  end
end
