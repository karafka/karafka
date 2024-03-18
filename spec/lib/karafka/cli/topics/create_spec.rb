# frozen_string_literal: true

RSpec.describe_current do
  subject(:create_topics) { described_class.new }

  describe '#call' do
    let(:declaratives_routing_topics) { [double, double] }
    let(:existing_topics_names) { ['existing_topic'] }

    before do
      allow(create_topics)
        .to receive(:declaratives_routing_topics)
        .and_return(declaratives_routing_topics)

      allow(create_topics)
        .to receive(:existing_topics_names)
        .and_return(existing_topics_names)

      # Suppress console output
      allow(create_topics)
        .to receive(:puts)

      declaratives_routing_topics.each_with_index do |topic, index|
        allow(topic).to receive(:name).and_return("topic_#{index}")

        declaratives = instance_double(
          Karafka::Routing::Features::Declaratives::Config,
          partitions: 1,
          replication_factor: 1,
          details: {}
        )

        allow(topic).to receive(:declaratives).and_return(declaratives)
      end

      allow(Karafka::Admin).to receive(:create_topic)
    end

    context 'when all topics already exist' do
      before do
        allow(create_topics)
          .to receive(:existing_topics_names)
          .and_return(%w[topic_0 topic_1])
      end

      it 'does not create any topics and returns false' do
        expect(create_topics.call).to be_falsey
        expect(Karafka::Admin).not_to have_received(:create_topic)
      end
    end

    context 'when some topics do not exist' do
      it 'creates only the non-existing topics and returns true' do
        expect(create_topics.call).to be_truthy

        expect(Karafka::Admin).to have_received(:create_topic).with(
          'topic_1',
          anything,
          anything,
          anything
        ).once
      end
    end

    context 'when no topics exist' do
      let(:existing_topics_names) { [] }

      it 'creates all topics and returns true' do
        expect(create_topics.call).to be_truthy

        expect(Karafka::Admin).to have_received(:create_topic).twice
      end
    end
  end
end
