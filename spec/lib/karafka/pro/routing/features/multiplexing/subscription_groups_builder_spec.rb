# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:expansion) do
    Class.new do
      include Karafka::Pro::Routing::Features::Multiplexing::SubscriptionGroupsBuilder
    end.new.expand(topics_array)
  end

  let(:topic1) { build(:routing_topic) }
  let(:topic2) { build(:routing_topic) }
  let(:topics_array) { [topic1, topic2] }

  describe '#expand' do
    context 'when multiplexing is off' do
      before { topic1.subscription_group_details[:multiplexing_max] = 1 }

      it { expect(expansion.size).to eq(1) }
    end

    context 'when multiplexing is on with 3 copies' do
      before { topic1.subscription_group_details[:multiplexing_max] = 3 }

      it { expect(expansion.size).to eq(3) }

      it 'expect to share the same name' do
        names = []

        expansion.each do |topics|
          names += topics.map(&:name)
        end

        expect(names.uniq.size).to eq(1)
      end
    end
  end
end
