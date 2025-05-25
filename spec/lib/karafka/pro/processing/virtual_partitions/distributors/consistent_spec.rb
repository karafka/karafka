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

  let(:partitioner) { ->(msg) { msg.raw_key.to_s.sum } }
  let(:reducer) { ->(key) { key % 3 } }
  let(:max_partitions) { 3 }

  subject(:distributor) { described_class.new(config) }

  describe '#call' do
    let(:messages) do
      [
        build(:messages_message, raw_key: 'a'),
        build(:messages_message, raw_key: 'b'),
        build(:messages_message, raw_key: 'a'),
        build(:messages_message, raw_key: 'c')
      ]
    end

    it 'groups messages by partition key and sorts by size' do
      result = distributor.call(messages)

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([1, 2, 0])
      expect(result[1].size).to eq(2)
      expect(result[2].size).to eq(1)
      expect(result[0].size).to eq(1)
    end
  end
end
