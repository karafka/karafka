# frozen_string_literal: true

RSpec.describe Karafka::AssignmentStrategies::RoundRobin do
  describe '#call' do
    subject(:call) { strategy.call(cluster: cluster, members: members, partitions: partitions) }

    let(:strategy) { described_class.new }
    let(:cluster) { instance_double(Array) }
    let(:members) { Hash[(1..5).map { |i| ["member#{i}", nil] }] }
    let(:delegator) { strategy.__getobj__ }

    let(:original_result) do
      delegator.call(cluster: cluster, members: members, partitions: partitions)
    end

    let(:partitions) do
      (1..10).map do |i|
        OpenStruct.new(name: "partition#{i}", topic: 'greetings', partition_id: i)
      end
    end

    let(:expected_result) do
      {
        'member1' => [
          OpenStruct.new(name: 'partition1', topic: 'greetings', partition_id: 1),
          OpenStruct.new(name: 'partition6', topic: 'greetings', partition_id: 6)
        ],
        'member2' => [
          OpenStruct.new(name: 'partition2', topic: 'greetings', partition_id: 2),
          OpenStruct.new(name: 'partition7', topic: 'greetings', partition_id: 7)
        ],
        'member3' => [
          OpenStruct.new(name: 'partition3', topic: 'greetings', partition_id: 3),
          OpenStruct.new(name: 'partition8', topic: 'greetings', partition_id: 8)
        ],
        'member4' => [
          OpenStruct.new(name: 'partition4', topic: 'greetings', partition_id: 4),
          OpenStruct.new(name: 'partition9', topic: 'greetings', partition_id: 9)
        ],
        'member5' => [
          OpenStruct.new(name: 'partition5', topic: 'greetings', partition_id: 5),
          OpenStruct.new(name: 'partition10', topic: 'greetings', partition_id: 10)
        ]
      }
    end

    it 'is delegated to Kafka::RoundRobinAssignmentStrategy' do
      expect(delegator).to receive(:call)
        .with(cluster: cluster, members: members, partitions: partitions)
        .and_return(original_result)

      expect(call).to eq expected_result
    end
  end
end
