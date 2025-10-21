# frozen_string_literal: true

RSpec.describe Karafka::Admin::Contracts::Replication do
  subject(:contract) { described_class.new }

  let(:base_config) do
    {
      topic: 'test-topic',
      to: 3
    }
  end

  let(:topic_info) do
    {
      partitions: [
        { partition_id: 0 },
        { partition_id: 1 }
      ]
    }
  end

  let(:cluster_info) do
    {
      brokers: [
        { node_id: 1 },
        { node_id: 2 },
        { node_id: 3 },
        { node_id: 4 }
      ]
    }
  end

  let(:config) do
    base_config.merge(
      current_rf: 2,
      broker_count: 4,
      topic_info: topic_info,
      cluster_info: cluster_info
    )
  end

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }

    context 'with manual broker assignment' do
      let(:config_with_brokers) do
        config.merge(brokers: { 0 => [1, 2, 3], 1 => [2, 3, 4] })
      end

      it { expect(contract.call(config_with_brokers)).to be_success }
    end
  end

  context 'when topic is invalid' do
    context 'when topic is empty' do
      let(:config) { base_config.merge(topic: '') }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when topic is not a string' do
      let(:config) { base_config.merge(topic: 123) }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when to (target replication factor) is invalid' do
    context 'when to is not an integer' do
      let(:config) { base_config.merge(to: 'three') }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when to is less than 1' do
      let(:config) { base_config.merge(to: 0) }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when target replication factor is not higher than current' do
    let(:config) { base_config.merge(current_rf: 2, to: 2) }

    it { expect(contract.call(config)).not_to be_success }

    it 'includes the correct error message' do
      result = contract.call(config)
      expect(result.errors.to_h).to include(
        to: 'target replication factor must be higher than current'
      )
    end
  end

  context 'when target replication factor exceeds available brokers' do
    let(:config) { base_config.merge(broker_count: 2, to: 3) }

    it { expect(contract.call(config)).not_to be_success }

    it 'includes the correct error message' do
      result = contract.call(config)
      expect(result.errors.to_h).to include(
        to: 'target replication factor cannot exceed available broker count'
      )
    end
  end

  context 'when brokers parameter is invalid' do
    context 'when brokers is not a hash' do
      let(:config) { base_config.merge(brokers: 'invalid') }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when manual broker assignment is invalid' do
    let(:config_with_validation_data) do
      config.merge(brokers: invalid_brokers)
    end

    context 'when missing partitions' do
      let(:invalid_brokers) { { 0 => [1, 2, 3] } } # Missing partition 1

      it { expect(contract.call(config_with_validation_data)).not_to be_success }

      it 'includes the correct error message' do
        result = contract.call(config_with_validation_data)
        expect(result.errors.to_h).to include(brokers: 'manual assignment missing partitions')
      end
    end

    context 'when partition does not exist' do
      # Partition 5 doesn't exist
      let(:invalid_brokers) { { 0 => [1, 2, 3], 1 => [2, 3, 4], 5 => [1, 2, 3] } }

      it { expect(contract.call(config_with_validation_data)).not_to be_success }

      it 'includes the correct error message' do
        result = contract.call(config_with_validation_data)
        expect(result.errors.to_h).to include(brokers: 'partition does not exist in topic')
      end
    end

    context 'when broker count does not match target replication factor' do
      # Partition 0 has 2 brokers, should be 3
      let(:invalid_brokers) { { 0 => [1, 2], 1 => [2, 3, 4] } }

      it { expect(contract.call(config_with_validation_data)).not_to be_success }

      it 'includes the correct error message' do
        result = contract.call(config_with_validation_data)
        expect(result.errors.to_h).to include(
          brokers: 'partition broker count does not match target replication factor'
        )
      end
    end

    context 'when partition has duplicate brokers' do
      let(:invalid_brokers) { { 0 => [1, 2, 2], 1 => [2, 3, 4] } } # Partition 0 has duplicate broker 2

      it { expect(contract.call(config_with_validation_data)).not_to be_success }

      it 'includes the correct error message' do
        result = contract.call(config_with_validation_data)
        expect(result.errors.to_h).to include(brokers: 'partition has duplicate brokers')
      end
    end

    context 'when partition references non-existent brokers' do
      let(:invalid_brokers) { { 0 => [1, 2, 5], 1 => [2, 3, 4] } } # Broker 5 doesn't exist

      it { expect(contract.call(config_with_validation_data)).not_to be_success }

      it 'includes the correct error message' do
        result = contract.call(config_with_validation_data)
        expect(result.errors.to_h).to include(brokers: 'partition references non-existent brokers')
      end
    end
  end

  context 'when brokers is nil (automatic assignment)' do
    let(:config) { base_config.merge(brokers: nil) }

    it { expect(contract.call(config)).to be_success }
  end
end
