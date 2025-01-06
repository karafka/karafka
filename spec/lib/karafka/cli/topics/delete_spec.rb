# frozen_string_literal: true

RSpec.describe_current do
  subject(:delete_topics) { described_class.new }

  describe '#call' do
    let(:declaratives_routing_topics) { [double, double] }
    let(:existing_topics_names) { %w[existing_topic] }

    before do
      allow(delete_topics)
        .to receive_messages(
          declaratives_routing_topics: declaratives_routing_topics,
          existing_topics_names: existing_topics_names,
          # Suppress console output
          puts: nil
        )

      declaratives_routing_topics.each_with_index do |topic, index|
        declaratives = instance_double(Karafka::Routing::Features::Declaratives::Config)

        allow(topic).to receive_messages(
          name: "topic_#{index}",
          # Assuming the class and namespace for declaratives setup as before
          declaratives: declaratives
        )
      end

      allow(Karafka::Admin).to receive(:delete_topic)
    end

    context 'when all topics exist' do
      let(:existing_topics_names) { %w[topic_0 topic_1] }

      it 'deletes all topics and returns true' do
        expect(delete_topics.call).to be_truthy

        expect(Karafka::Admin).to have_received(:delete_topic).twice
      end
    end

    context 'when some topics do not exist' do
      let(:existing_topics_names) { %w[topic_0] }

      it 'deletes existing topics, skips non-existing ones, and returns true' do
        expect(delete_topics.call).to be_truthy

        expect(Karafka::Admin).to have_received(:delete_topic).with('topic_0').once
      end
    end

    context 'when no topics exist' do
      let(:existing_topics_names) { [] }

      it 'does not delete any topics and returns false' do
        expect(delete_topics.call).to be_falsey

        expect(Karafka::Admin).not_to have_received(:delete_topic)
      end
    end
  end
end
