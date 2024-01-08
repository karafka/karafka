# frozen_string_literal: true

RSpec.describe_current do
  subject(:builder) { Karafka::Routing::Builder.new }

  let(:topic) { builder.first.topics.first }

  describe '#multiplexing' do
    before do
      builder.draw do
        consumer_group(:a) do
          subscription_group(:test) do
            multiplexing(count: 2, dynamic: false)

            topic(:test) { active(false) }
          end
        end
      end
    end

    it { expect(topic.subscription_group_details[:multiplexing_count]).to eq(2) }
    it { expect(topic.subscription_group_details[:multiplexing_dynamic]).to eq(false) }
    it { expect(topic.subscription_group_details[:name]).to eq('test') }
  end
end
