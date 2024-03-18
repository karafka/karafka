# frozen_string_literal: true

RSpec.describe_current do
  subject(:delete_topics) { described_class.new }

  describe '#call' do
    let(:declaratives_routing_topics) { [double, double] }
    let(:existing_topics_names) { %w[existing_topic] }

    before do
      allow(delete_topics)
        .to receive(:declaratives_routing_topics)
        .and_return(declaratives_routing_topics)

      allow(delete_topics)
        .to receive(:existing_topics_names)
        .and_return(existing_topics_names)

      allow(delete_topics)
        .to receive(:puts) # Suppress console output

      declaratives_routing_topics.each_with_index do |topic, index|
        allow(topic).to receive(:name).and_return("topic_#{index}")

        # Assuming the class and namespace for declaratives setup as before
        declaratives = instance_double(Karafka::Routing::Features::Declaratives::Config)

        allow(topic).to receive(:declaratives).and_return(declaratives)
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
