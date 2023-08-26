# frozen_string_literal: true

RSpec.describe_current do
  subject(:topics) { ::Karafka::Routing::Topics.new([]) }

  let(:topic) { build(:routing_topic) }

  describe '#find' do
    before { topics << topic }

    context 'when topic with given name exists' do
      it { expect(topics.find(topic.name)).to eq(topic) }
    end

    context 'when topic with given name does not exist and no patterns' do
      it 'expect to raise an exception as this should never happen' do
        expect { topics.find('na') }.to raise_error(Karafka::Errors::TopicNotFoundError, 'na')
      end
    end

    context 'when patterns exist but none matches' do
      let(:expected_errror) do
        ::Karafka::Pro::Routing::Features::Patterns::Errors::PatternNotMatchedError
      end

      let(:pattern_topic) do
        topic = build(:routing_topic)
        topic.patterns(
          active: true,
          type: :matcher,
          pattern: ::Karafka::Pro::Routing::Features::Patterns::Pattern.new(/xda/, -> {})
        )
        topic
      end

      before { topics << pattern_topic }

      it ' expect to raise an error as this should not happen' do
        expect { topics.find('na') }.to raise_error(expected_errror, 'na')
      end
    end

    context 'when patterns exist and matched' do
      let(:expected_errror) do
        ::Karafka::Pro::Routing::Features::Patterns::Errors::PatternNotMatchedError
      end

      let(:pattern_topic) do
        p_topic = build(:routing_topic, consumer_group: topic.consumer_group, name: 'exists')
        pattern = ::Karafka::Pro::Routing::Features::Patterns::Pattern.new(/.*/, ->(_) {})
        pattern.topic = p_topic
        p_topic.patterns(
          active: true,
          type: :matcher,
          pattern: pattern
        )
        p_topic
      end

      before { topics << pattern_topic }

      it ' expect to raise an error as this should not happen' do
        expect(topics.find('exists')).to eq(pattern_topic)
      end
    end
  end
end
