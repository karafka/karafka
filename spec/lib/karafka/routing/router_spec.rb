# frozen_string_literal: true

RSpec.describe_current do
  subject(:router) { described_class }

  before do
    Karafka::App.config.internal.routing.builder.clear

    Karafka::App.config.internal.routing.builder.draw do
      topic :topic_name1 do
        consumer Class.new(Karafka::BaseConsumer)
      end
    end
  end

  describe '.find_by' do
    context 'when we look for non existing topic by name' do
      let(:name) { rand.to_s }
      let(:expected_error) { Karafka::Errors::NonMatchingRouteError }

      it { expect(router.find_by(name: name)).to eq(nil) }
    end

    context 'when we look for existing topic' do
      let(:topic) { Karafka::App.config.internal.routing.builder.last.topics.last }
      let(:name) { topic.name }

      it { expect(router.find_by(name: name)).to eq topic }
    end
  end

  describe '.find_or_initialize_by_name' do
    subject(:found_topic) { router.find_or_initialize_by_name(name) }

    context 'when we look for non existing topic' do
      let(:name) { rand.to_s }

      it 'expect to create it with consumer group reference' do
        expect(found_topic.consumer_group).not_to eq(nil)
      end

      it 'expect to match the name' do
        expect(found_topic.name).to eq(name)
      end

      it 'expect to have default deserializer' do
        expect(found_topic.deserializer).to eq(Karafka::App.config.deserializer)
      end
    end

    context 'when we look for existing topic' do
      let(:topic) { Karafka::App.config.internal.routing.builder.last.topics.last }
      let(:name) { topic.name }

      it { expect(router.find_by(name: name)).to eq(topic) }
    end
  end
end
