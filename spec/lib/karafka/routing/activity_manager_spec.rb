# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  describe '#include and #active?' do
    context 'when trying to include something of an invalid type' do
      let(:expected_error) { ::Karafka::Errors::UnsupportedCaseError }

      it { expect { manager.include('na', 1) }.to raise_error(expected_error) }
    end

    context 'when nothing is included and nothing is excluded' do
      it { expect(manager.active?(:subscription_groups, 'test')).to eq(true) }
    end

    context 'when topic is in the included' do
      before { manager.include(:topics, 'topic1') }

      it { expect(manager.active?(:topics, 'topic1')).to eq(true) }
      it { expect(manager.active?(:topics, 'topic2')).to eq(false) }
    end
  end

  describe '#exclude and #active?' do
    context 'when trying to exclude something of an invalid type' do
      let(:expected_error) { ::Karafka::Errors::UnsupportedCaseError }

      it { expect { manager.exclude('na', 1) }.to raise_error(expected_error) }
    end

    context 'when topic is in the excluded only' do
      before { manager.exclude(:topics, 'topic1') }

      it { expect(manager.active?(:topics, 'topic1')).to eq(false) }
      it { expect(manager.active?(:topics, 'topic2')).to eq(true) }
    end

    context 'when topic is in the included and excluded at the same time' do
      before do
        manager.include(:topics, 'topic1')
        manager.exclude(:topics, 'topic1')
      end

      it { expect(manager.active?(:topics, 'topic1')).to eq(true) }
      it { expect(manager.active?(:topics, 'topic2')).to eq(false) }
    end

    context 'when different topics are both included and excluded' do
      before do
        manager.include(:topics, 'topic1')
        manager.exclude(:topics, 'topic2')
      end

      it { expect(manager.active?(:topics, 'topic1')).to eq(true) }
      it { expect(manager.active?(:topics, 'topic2')).to eq(false) }
    end
  end

  describe '#to_h' do
    before do
      manager.include(:topics, 't1')
      manager.exclude(:topics, 't2')
      manager.include(:subscription_groups, 'sg1')
      manager.exclude(:subscription_groups, 'sg2')
      manager.include(:consumer_groups, 'cg1')
      manager.exclude(:consumer_groups, 'cg2')
    end

    it { expect(manager.to_h[:include_topics]).to eq(%w[t1]) }
    it { expect(manager.to_h[:exclude_topics]).to eq(%w[t2]) }
    it { expect(manager.to_h[:include_subscription_groups]).to eq(%w[sg1]) }
    it { expect(manager.to_h[:exclude_subscription_groups]).to eq(%w[sg2]) }
    it { expect(manager.to_h[:include_consumer_groups]).to eq(%w[cg1]) }
    it { expect(manager.to_h[:exclude_consumer_groups]).to eq(%w[cg2]) }
  end

  describe '#clear' do
    before do
      manager.include(:consumer_groups, 'na')
      manager.include(:subscription_groups, 'na')
      manager.include(:topics, 'na')

      manager.clear
    end

    it { expect(manager.to_h.values.all?(&:empty?)).to eq(true) }
  end
end
