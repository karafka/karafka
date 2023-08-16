# frozen_string_literal: true

RSpec.describe_current do
  subject(:cg) { build(:routing_consumer_group) }

  let(:adding_pattern) do
    cg.public_send(:pattern=, /test/) do
      consumer Class.new
    end
  end

  it { expect(cg.patterns).to be_empty }

  describe '#patterns and #pattern=' do
    it do
      expect { adding_pattern }.to change(cg.patterns, :size).from(0).to(1)
    end

    it do
      expect { adding_pattern }.to change(cg.topics, :size).from(0).to(1)
    end

    it do
      adding_pattern

      expect(cg.topics.last.name).to eq(cg.patterns.last.topic_name)
    end
  end

  describe '#to_h' do
    context 'when no patterns' do
      it { expect(cg.to_h[:patterns]).to eq([]) }
    end

    context 'when there are patterns' do
      before { adding_pattern }

      it 'expect to add patterns to hash' do
        expect(cg.to_h[:patterns]).to eq([{ regexp: /test/, topic_name: cg.topics.last.name }])
      end
    end
  end
end
