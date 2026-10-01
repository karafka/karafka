# frozen_string_literal: true

RSpec.describe Karafka::Routing::SubscriptionGroup do
  subject(:subscription_group) { groups.first.subscription_groups.first }

  let(:kafka) { { "bootstrap.servers": "127.0.0.1:9092" } }
  let(:groups) do
    topic_kafka = kafka

    Karafka::Routing::Builder.new.draw do
      share_group :share_group_name do
        topic :topic_name do
          consumer Class.new(Karafka::ShareConsumer)
          max_messages 7
          kafka(topic_kafka)
        end
      end
    end
  end

  describe "#kafka for share groups" do
    it "uses max_messages as the max.poll.records default" do
      expect(subscription_group.kafka[:"max.poll.records"]).to eq(7)
    end

    context "when max.poll.records is set explicitly" do
      let(:kafka) { { "bootstrap.servers": "127.0.0.1:9092", "max.poll.records": 50 } }

      it { expect(subscription_group.kafka[:"max.poll.records"]).to eq(50) }
    end
  end
end
