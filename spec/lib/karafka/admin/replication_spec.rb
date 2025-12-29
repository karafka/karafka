# frozen_string_literal: true

RSpec.describe Karafka::Admin::Replication do
  let(:topic_name) { 'test-topic' }
  let(:mock_topic_info) do
    {
      partitions: [
        {
          partition_id: 0,
          replicas: [
            OpenStruct.new(node_id: 1),
            OpenStruct.new(node_id: 2)
          ]
        },
        {
          partition_id: 1,
          replicas: [
            OpenStruct.new(node_id: 2),
            OpenStruct.new(node_id: 3)
          ]
        }
      ]
    }
  end

  let(:mock_cluster_info) do
    OpenStruct.new(
      brokers: [
        OpenStruct.new(node_id: 1, host: 'broker1', port: 9092),
        OpenStruct.new(node_id: 2, host: 'broker2', port: 9092),
        OpenStruct.new(node_id: 3, host: 'broker3', port: 9092),
        OpenStruct.new(node_id: 4, host: 'broker4', port: 9092)
      ]
    )
  end

  let(:cluster_info_for_instance) do
    {
      brokers: [
        { node_id: 1, host: 'broker1:9092' },
        { node_id: 2, host: 'broker2:9092' },
        { node_id: 3, host: 'broker3:9092' }
      ]
    }
  end

  let(:partitions_assignment) { { 0 => [1, 2, 3], 1 => [2, 3, 1] } }

  let(:plan_instance) do
    described_class.new(
      topic: topic_name,
      current_replication_factor: 2,
      target_replication_factor: 3,
      partitions_assignment: partitions_assignment,
      cluster_info: cluster_info_for_instance
    )
  end

  describe '.plan' do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_topic_info)
        .with(topic_name).and_return(mock_topic_info)
      allow_any_instance_of(described_class).to receive(:fetch_cluster_info).and_return(
        {
          brokers: mock_cluster_info.brokers.map do |broker|
            { node_id: broker.node_id, host: "#{broker.host}:#{broker.port}" }
          end
        }
      )
    end

    context 'when increasing replication factor with automatic assignment' do
      let(:plan) { described_class.plan(topic: topic_name, to: 3) }

      it 'returns a Replication object' do
        expect(plan).to be_a(described_class)
      end

      it 'correctly identifies current and target replication factors' do
        expect(plan.current_replication_factor).to eq(2)
        expect(plan.target_replication_factor).to eq(3)
        expect(plan.topic).to eq(topic_name)
      end

      it 'generates partition assignments with additional replicas' do
        assignments = plan.partitions_assignment
        expect(assignments[0]).to include(1, 2) # Original replicas
        expect(assignments[0].size).to eq(3) # Now has 3 replicas
        expect(assignments[1]).to include(2, 3) # Original replicas
        expect(assignments[1].size).to eq(3) # Now has 3 replicas
      end

      it 'generates valid reassignment JSON' do
        json_data = JSON.parse(plan.reassignment_json)
        expect(json_data['version']).to eq(1)
        expect(json_data['partitions']).to be_an(Array)
        expect(json_data['partitions'].size).to eq(2)

        partition_0 = json_data['partitions'].find { |p| p['partition'] == 0 }
        expect(partition_0['topic']).to eq(topic_name)
        expect(partition_0['replicas'].size).to eq(3)
      end

      it 'includes execution commands' do
        commands = plan.execution_commands
        expect(commands).to have_key(:generate)
        expect(commands).to have_key(:execute)
        expect(commands).to have_key(:verify)

        expect(commands[:execute]).to include('kafka-reassign-partitions.sh')
        expect(commands[:execute]).to include('--execute')
      end

      it 'provides step-by-step instructions' do
        expect(plan.steps).to be_an(Array)
        expect(plan.steps.join(' ')).to include('export')
        expect(plan.steps.join(' ')).to include('execute')
        expect(plan.steps.join(' ')).to include('verify')
      end

      it 'generates informative summary' do
        summary = plan.summary
        expect(summary).to include(topic_name)
        expect(summary).to include('Current replication factor: 2')
        expect(summary).to include('Target replication factor: 3')
        expect(summary).to include('Total partitions: 2')
      end
    end

    context 'when target replication factor is not higher than current' do
      it 'raises InvalidConfigurationError for equal replication factor' do
        expect do
          described_class.plan(topic: topic_name, to: 2)
        end.to raise_error(
          Karafka::Errors::InvalidConfigurationError,
          /target replication factor must be higher than current/
        )
      end

      it 'raises InvalidConfigurationError for lower replication factor' do
        expect do
          described_class.plan(topic: topic_name, to: 1)
        end.to raise_error(
          Karafka::Errors::InvalidConfigurationError,
          /target replication factor must be higher than current/
        )
      end
    end

    context 'when target replication factor exceeds available brokers' do
      it 'raises InvalidConfigurationError' do
        expect do
          described_class.plan(topic: topic_name, to: 5)
        end.to raise_error(
          Karafka::Errors::InvalidConfigurationError,
          /target replication factor cannot exceed available broker count/
        )
      end
    end

    context 'when using manual broker assignment' do
      let(:manual_brokers) do
        {
          0 => [1, 2, 3],
          1 => [2, 3, 4]
        }
      end

      let(:plan) { described_class.plan(topic: topic_name, to: 3, brokers: manual_brokers) }

      it 'uses the specified broker assignments' do
        expect(plan.partitions_assignment).to eq(manual_brokers)
      end

      it 'returns a valid Replication object' do
        expect(plan).to be_a(described_class)
        expect(plan.target_replication_factor).to eq(3)
      end

      context 'when manual assignment is missing partitions' do
        let(:incomplete_brokers) { { 0 => [1, 2, 3] } }

        it 'raises InvalidConfigurationError' do
          expect do
            described_class.plan(topic: topic_name, to: 3, brokers: incomplete_brokers)
          end.to raise_error(
            Karafka::Errors::InvalidConfigurationError,
            /manual assignment missing partitions/
          )
        end
      end

      context 'when manual assignment has wrong broker count' do
        let(:wrong_count_brokers) do
          {
            0 => [1, 2], # Only 2 brokers instead of 3
            1 => [2, 3, 4]
          }
        end

        it 'raises InvalidConfigurationError' do
          expect do
            described_class.plan(topic: topic_name, to: 3, brokers: wrong_count_brokers)
          end.to raise_error(
            Karafka::Errors::InvalidConfigurationError,
            /partition broker count does not match target replication factor/
          )
        end
      end

      context 'when manual assignment has duplicate brokers' do
        let(:duplicate_brokers) do
          {
            0 => [1, 2, 2],  # Broker 2 appears twice
            1 => [2, 3, 4]
          }
        end

        it 'raises InvalidConfigurationError' do
          expect do
            described_class.plan(topic: topic_name, to: 3, brokers: duplicate_brokers)
          end.to raise_error(
            Karafka::Errors::InvalidConfigurationError,
            /partition has duplicate brokers/
          )
        end
      end

      context 'when manual assignment references non-existent brokers' do
        let(:invalid_brokers) do
          {
            0 => [1, 2, 5],  # Broker 5 doesn't exist
            1 => [2, 3, 4]
          }
        end

        it 'raises InvalidConfigurationError' do
          expect do
            described_class.plan(topic: topic_name, to: 3, brokers: invalid_brokers)
          end.to raise_error(
            Karafka::Errors::InvalidConfigurationError,
            /partition references non-existent brokers/
          )
        end
      end
    end
  end

  describe '.rebalance' do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_topic_info)
        .with(topic_name).and_return(mock_topic_info)
      allow_any_instance_of(described_class).to receive(:fetch_cluster_info).and_return(
        {
          brokers: mock_cluster_info.brokers.map do |broker|
            { node_id: broker.node_id, host: "#{broker.host}:#{broker.port}" }
          end
        }
      )
    end

    it 'generates a rebalancing plan without changing replication factor' do
      plan = described_class.rebalance(topic: topic_name)

      expect(plan.current_replication_factor).to eq(2)
      expect(plan.target_replication_factor).to eq(2)
      expect(plan.partitions_assignment.values.all? { |replicas| replicas.size == 2 }).to be(true)
    end
  end

  describe '#export_to_file' do
    let(:temp_file) { Tempfile.new(['reassignment', '.json']) }

    after { temp_file.unlink }

    it 'exports JSON to specified file' do
      file_path = plan_instance.export_to_file(temp_file.path)

      expect(file_path).to eq(temp_file.path)
      expect(File.exist?(temp_file.path)).to be(true)

      content = File.read(temp_file.path)
      json_data = JSON.parse(content)
      expect(json_data['version']).to eq(1)
      expect(json_data['partitions']).to be_an(Array)
    end
  end

  describe '#summary' do
    it 'provides comprehensive plan summary' do
      summary = plan_instance.summary

      expect(summary).to include('test-topic')
      expect(summary).to include('Current replication factor: 2')
      expect(summary).to include('Target replication factor: 3')
      expect(summary).to include('Total partitions: 2')
      expect(summary).to include('Available brokers: 3')
      expect(summary).to include('increase replication by adding 1 replica')
    end
  end

  describe '#reassignment_json' do
    it 'generates valid Kafka reassignment JSON format' do
      json_data = JSON.parse(plan_instance.reassignment_json)

      expect(json_data).to include('version' => 1, 'partitions' => anything)
      expect(json_data['partitions']).to be_an(Array)
      expect(json_data['partitions'].size).to eq(2)

      partition_data = json_data['partitions'].first
      expect(partition_data).to include('topic', 'partition', 'replicas')
      expect(partition_data['topic']).to eq(topic_name)
      expect(partition_data['replicas']).to be_an(Array)
    end
  end

  describe '#execution_commands' do
    it 'provides all necessary Kafka commands' do
      commands = plan_instance.execution_commands

      expect(commands).to include(:generate, :execute, :verify)

      commands.each_value do |command|
        expect(command).to include('kafka-reassign-partitions.sh')
        expect(command).to include('--bootstrap-server')
        expect(command).to include('--reassignment-json-file')
      end
    end
  end

  describe 'Karafka::Admin.plan_topic_replication' do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_topic_info)
        .with(topic_name).and_return(mock_topic_info)
      allow_any_instance_of(described_class).to receive(:fetch_cluster_info).and_return(
        {
          brokers: mock_cluster_info.brokers.map do |broker|
            { node_id: broker.node_id, host: "#{broker.host}:#{broker.port}" }
          end
        }
      )
    end

    it 'delegates to Replication correctly' do
      result = Karafka::Admin.plan_topic_replication(topic: topic_name, replication_factor: 3)

      expect(result).to be_a(described_class)
      expect(result.topic).to eq(topic_name)
      expect(result.target_replication_factor).to eq(3)
    end

    it 'passes manual broker assignments when provided' do
      manual_brokers = { 0 => [1, 2, 3], 1 => [2, 3, 4] }

      result = Karafka::Admin.plan_topic_replication(
        topic: topic_name,
        replication_factor: 3,
        brokers: manual_brokers
      )

      expect(result).to be_a(described_class)
      expect(result.partitions_assignment).to eq(manual_brokers)
    end
  end
end
