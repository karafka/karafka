# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:builder) { Karafka::Routing::Builder.new }

  let(:topic) { builder.first.topics.first }

  describe '#multiplexing' do
    before do
      builder.draw do
        consumer_group(:a) do
          subscription_group(:test) do
            multiplexing(min: 2, max: 3)

            topic(:test) { active(false) }
          end
        end
      end
    end

    it { expect(topic.subscription_group_details[:multiplexing_min]).to eq(2) }
    it { expect(topic.subscription_group_details[:multiplexing_max]).to eq(3) }
    it { expect(topic.subscription_group_details[:name]).to eq('test') }
  end
end
