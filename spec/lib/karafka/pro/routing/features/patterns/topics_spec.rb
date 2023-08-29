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
      let(:pattern_topic) { build(:pattern_routing_topic) }

      before { topics << pattern_topic }

      it ' expect to raise an error as this should not happen' do
        expect { topics.find('na') }.to raise_error(Karafka::Errors::TopicNotFoundError, 'na')
      end
    end

    context 'when patterns exist and matched' do
      let(:pattern_topic) { build(:pattern_routing_topic, regexp: /.*/) }

      before { topics << pattern_topic }

      it ' expect to raise an error as this should not happen' do
        expect(topics.find('exists').patterns.discovered?).to eq(true)
      end
    end
  end
end
