# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:expanded) do
    klass = described_class

    Class.new do
      extend klass
    end
  end

  describe '#topic_unique_key' do
    let(:topic) { { name: 'test', subscription_group_details: 'sg', other: 'na' } }

    it { expect(expanded.topic_unique_key(topic)).to eq(%w[test sg]) }
  end
end
