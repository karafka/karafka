# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#adaptive_iterator' do
    context 'when we use adaptive_iterator without any arguments' do
      it 'expects to initialize with defaults' do
        expect(topic.adaptive_iterator.active?).to eq(false)
        expect(topic.adaptive_iterator.safety_margin).to eq(10)
        expect(topic.adaptive_iterator.marking_method).to eq(:mark_as_consumed)
        expect(topic.adaptive_iterator.clean_after_yielding).to eq(true)
      end
    end

    context 'when we use adaptive_iterator with custom safety margin' do
      it 'expects to use the provided safety margin' do
        safety_margin = 5
        topic.adaptive_iterator(safety_margin: safety_margin)
        expect(topic.adaptive_iterator.safety_margin).to eq(safety_margin)
      end
    end

    context 'when we use custom marking method' do
      it 'expects to use the provided marking method' do
        marking_method = :custom_mark_method
        topic.adaptive_iterator(marking_method: marking_method)
        expect(topic.adaptive_iterator.marking_method).to eq(marking_method)
      end
    end

    context 'when we disable clean_after_yielding' do
      it 'expects clean_after_yielding to be false' do
        topic.adaptive_iterator(clean_after_yielding: false)
        expect(topic.adaptive_iterator.clean_after_yielding).to eq(false)
      end
    end
  end

  describe '#adaptive_iterator?' do
    context 'when adaptive_iterator is not active' do
      before { topic.adaptive_iterator }

      it { expect(topic.adaptive_iterator?).to eq(false) }
    end
  end

  describe '#to_h' do
    it 'expects to include adaptive_iterator configuration in the hash' do
      expect(topic.to_h[:adaptive_iterator]).to eq(topic.adaptive_iterator.to_h)
    end
  end
end
