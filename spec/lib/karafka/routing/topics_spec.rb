# frozen_string_literal: true

RSpec.describe_current do
  subject(:topics) { described_class.new([]) }

  let(:topic) { build(:routing_topic) }

  describe '#empty?' do
    context 'when it is a new topics group' do
      it { expect(topics.empty?).to eq(true) }
    end

    context 'when there are some topics' do
      before { topics << topic }

      it { expect(topics.empty?).to eq(false) }
    end
  end

  describe '#last' do
    context 'when there are no topics' do
      it { expect(topics.last).to eq(nil) }
    end

    context 'when there are some topics' do
      before { topics << topic }

      it { expect(topics.last).to eq(topic) }
    end
  end

  describe '#size' do
    context 'when there are no topics' do
      it { expect(topics.size).to eq(0) }
    end

    context 'when there are some topics' do
      before { topics << topic }

      it { expect(topics.size).to eq(1) }
    end
  end

  describe '#each' do
    before { topics << topic }

    it { expect { |block| topics.each(&block) }.to yield_with_args(topic) }
  end

  describe '#find' do
    before { topics << topic }

    context 'when topic with given name exists' do
      it { expect(topics.find(topic.name)).to eq(topic) }
    end

    context 'when topic with given name does not exist' do
      it 'expect to raise an exception as this should never happen' do
        expect { topics.find('na') }.to raise_error(Karafka::Errors::TopicNotFoundError, 'na')
      end
    end
  end
end
