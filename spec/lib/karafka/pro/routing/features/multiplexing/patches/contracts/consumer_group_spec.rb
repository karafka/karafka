# frozen_string_literal: true

RSpec.describe_current do
  subject(:expanded) do
    klass = described_class

    Class.new do
      extend klass
    end
  end

  describe '#topic_unique_key' do
    let(:topic) { { name: 'test', subscription_group_name: 'sg', other: 'na' } }

    it { expect(expanded.topic_unique_key(topic)).to eq(%w[test sg]) }
  end
end
