# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:topic) { builder.first.topics.first }

  describe '#scheduled_messages' do
    context 'when defining recurring tasks without any extra settings' do
      before { builder.scheduled_messages(topics_namespace: 'test_namespace') }

      it { expect(topic.consumer).to eq(Karafka::Pro::ScheduledMessages::Consumer) }
      it { expect(topic.scheduled_messages?).to eq(true) }
    end

    context 'when defining recurring tasks with extra settings' do
      before do
        builder.scheduled_messages(topics_namespace: 'test_namespace') do
          max_messages 5
        end
      end

      it { expect(topic.consumer).to eq(Karafka::Pro::ScheduledMessages::Consumer) }
      it { expect(topic.scheduled_messages?).to eq(true) }
      it { expect(topic.max_messages).to eq(5) }
      it { expect(builder.first.topics.size).to eq(3) }
      it { expect(builder.size).to eq(1) }
    end

    context 'when defining multiple scheduled topics' do
      before do
        builder.scheduled_messages(topics_namespace: 'test_namespace1') do
          max_messages 5
        end

        builder.scheduled_messages(topics_namespace: 'test_namespace2')
      end

      it { expect(builder.first.topics.size).to eq(6) }
      it { expect(builder.size).to eq(1) }
    end
  end
end
