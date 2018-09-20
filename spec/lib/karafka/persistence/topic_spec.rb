# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Topic do
  subject(:persistence) { described_class }

  let(:group_id) { rand.to_s }
  let(:raw_topic_name) { rand.to_s }
  let(:mapped_topic_name) { raw_topic_name }
  let(:route_key) { "#{group_id}_#{mapped_topic_name}" }
  let(:topic) { build(:routing_topic) }

  describe '#fetch' do
    context 'when given topic has not been cached yet' do
      it 'expect to hit router and find it' do
        expect(Karafka::Routing::Router).to receive(:find).with(route_key).and_return(topic)
        expect(persistence.fetch(group_id, raw_topic_name)).to eq topic
      end
    end

    context 'when the topic is already cached' do
      before do
        allow(Karafka::Routing::Router).to receive(:find).with(route_key).and_return(topic).once
        persistence.fetch(group_id, raw_topic_name)
      end

      it 'expect not to hit router but used cached value' do
        expect(persistence.fetch(group_id, raw_topic_name)).to eq topic
      end
    end

    context 'when we use custom topic mapper' do
      let(:topic_mapper) { Karafka::Routing::TopicMapper.new }
      let(:mapped_topic_name) { "#{raw_topic_name}-remapped" }

      before do
        allow(Karafka::App.config)
          .to receive(:topic_mapper)
          .and_return(topic_mapper)

        allow(topic_mapper)
          .to receive(:incoming)
          .with(raw_topic_name)
          .and_return(mapped_topic_name)
      end

      it 'expect to remap and use remapped topic' do
        expect(Karafka::Routing::Router).to receive(:find).with(route_key).and_return(topic).once
        expect(persistence.fetch(group_id, raw_topic_name)).to eq topic
      end
    end
  end
end
