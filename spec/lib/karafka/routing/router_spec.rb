# frozen_string_literal: true

RSpec.describe_current do
  subject(:router) { described_class }

  before do
    Karafka::App.config.internal.routing_builder.clear

    Karafka::App.config.internal.routing_builder.draw do
      topic :topic_name1 do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end

  describe 'find' do
    context 'when we look for non existing topic' do
      let(:topic_id) { rand.to_s }
      let(:expected_error) { Karafka::Errors::NonMatchingRouteError }

      it { expect { router.find(topic_id) }.to raise_error(expected_error) }
    end

    context 'when we look for existing topic' do
      let(:topic) { Karafka::App.config.internal.routing_builder.last.topics.last }
      let(:topic_id) { topic.id }

      it { expect(router.find(topic_id)).to eq topic }
    end
  end
end
