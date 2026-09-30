# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new(topics) }

  let(:subscription_group) { groups.first.subscription_groups.first }
  let(:topics) { subscription_group.topics }
  let(:topic_name) { "topic_name1" }

  let(:groups) do
    Karafka::Routing::Builder.new.draw do
      share_group :group_name1 do
        topic :topic_name1 do
          consumer Class.new(Karafka::ShareConsumer)
        end
      end
    end
  end

  describe "#find_or_create" do
    context "when the coordinator is not in the buffer" do
      it "expect to create a new one for the given topic" do
        coordinator = buffer.find_or_create(topic_name)
        expect(coordinator).to be_a(Karafka::Processing::ShareGroups::Coordinator)
        expect(coordinator.topic.name).to eq(topic_name)
      end
    end

    context "when the coordinator is already in the buffer" do
      let(:existing) { buffer.find_or_create(topic_name) }

      before { existing }

      it "expect to re-use the existing one" do
        expect(buffer.find_or_create(topic_name)).to eq(existing)
      end
    end
  end

  describe "#reset" do
    let(:pre_reset) { buffer.find_or_create(topic_name) }

    before do
      pre_reset
      buffer.reset
    end

    it "expect to rebuild after reset" do
      expect(buffer.find_or_create(topic_name)).not_to eq(pre_reset)
    end
  end
end
