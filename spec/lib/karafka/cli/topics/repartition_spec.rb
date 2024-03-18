# frozen_string_literal: true

RSpec.describe Karafka::Cli::Topics::Repartition do
  subject(:repartition_topics) { described_class.new }

  let(:config_class) { Karafka::Routing::Features::Declaratives::Config }

  describe '#call' do
    let(:existing_topics) do
      [
        { topic_name: 'topic_1', partition_count: 1 },
        { topic_name: 'topic_2', partition_count: 2 }
      ]
    end

    let(:declaratives_routing_topics) do
      [
        instance_double(
          Karafka::Routing::Topic,
          name: 'topic_1',
          config: instance_double(config_class, partitions: 3)
        ),
        instance_double(
          Karafka::Routing::Topic,
          name: 'topic_2',
          config: instance_double(config_class, partitions: 2)
        ),
        instance_double(
          Karafka::Routing::Topic,
          name: 'topic_3',
          config: instance_double(config_class, partitions: 1)
        )
      ]
    end

    before do
      allow(repartition_topics)
        .to receive(:existing_topics)
        .and_return(existing_topics)
      allow(repartition_topics)
        .to receive(:declaratives_routing_topics)
        .and_return(declaratives_routing_topics)
      allow(repartition_topics)
        .to receive(:puts) # Suppress console output

      allow(Karafka::Admin).to receive(:create_partitions)
    end

    it 'repartitions topics that have less partitions than defined and skips the rest' do
      expect { repartition_topics.call }.not_to raise_error

      expect(Karafka::Admin).to have_received(:create_partitions).with('topic_1', 3).once
      expect(Karafka::Admin).not_to have_received(:create_partitions).with('topic_2', anything)
      expect(Karafka::Admin).not_to have_received(:create_partitions).with('topic_3', anything)
    end

    it 'returns true if any topic was repartitioned' do
      expect(repartition_topics.call).to be_truthy
    end

    context 'when no topics need repartitioning' do
      let(:declaratives_routing_topics) do
        [
          instance_double(
            Karafka::Routing::Topic,
            name: 'topic_2',
            config: instance_double(config_class, partitions: 2)
          )
        ]
      end

      it 'does not repartition any topic and returns false' do
        expect(repartition_topics.call).to be_falsey
        expect(Karafka::Admin).not_to have_received(:create_partitions)
      end
    end
  end
end
