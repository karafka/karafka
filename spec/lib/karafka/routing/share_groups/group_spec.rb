# frozen_string_literal: true

RSpec.describe Karafka::Routing::ShareGroups::Group do
  subject(:builder) { Karafka::Routing::Builder.new }

  after { builder.clear }

  let(:share_group) { builder.first }
  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }

  context "when drawing a share group" do
    before do
      cclass = consumer_class

      builder.draw do
        share_group "webhooks" do
          topic :events do
            consumer cclass
          end
        end
      end
    end

    it "expect to build a share group" do
      expect(share_group).to be_a(described_class)
      expect(share_group.name).to eq("webhooks")
      expect(share_group.id).to eq("webhooks")
    end

    it "expect the share group to report the share group type" do
      expect(share_group.group_type).to eq(:share)
      expect(share_group).to be_share_group
      expect(share_group).not_to be_consumer_group
    end

    it "expect its topics to be share topics carrying the share group type" do
      topic = share_group.topics.first

      expect(topic).to be_a(Karafka::Routing::ShareGroups::Topic)
      expect(topic).not_to be_a(Karafka::Routing::Topic)
      expect(topic.group_type).to eq(:share)
    end

    it "expect App-like helpers to differentiate it from consumer groups" do
      expect(builder.select(&:share_group?)).to eq([share_group])
      expect(builder.select(&:consumer_group?)).to be_empty
    end
  end

  context "when share topics do not inherit consumer-group feature DSL" do
    let(:consumer_topic) { builder.find(&:consumer_group?).topics.first }
    let(:share_topic) { builder.find(&:share_group?).topics.first }

    before do
      cclass = consumer_class

      builder.draw do
        consumer_group "cg" do
          topic(:a) { consumer cclass }
        end

        share_group "sg" do
          topic(:b) { consumer cclass }
        end
      end
    end

    # Every routing feature is defined under a single mode namespace
    # (`Features::ConsumerGroups::*`) and prepended onto the consumer topic only. None leak onto
    # the share topic. When the share-group runtime lands, the features share groups also need
    # (deserializers, etc.) will be duplicated under `Features::ShareGroups::*`.
    %i[dead_letter_queue deserializers declaratives config pause].each do |feature|
      it "expect a consumer topic to respond to :#{feature} and a share topic not to" do
        expect(consumer_topic).to respond_to(feature)
        expect(share_topic).not_to respond_to(feature)
      end
    end

    it "expect the share topic to_h to omit consumer-group only keys" do
      expect(consumer_topic.to_h).to include(:deserializers, :pause)
      expect(share_topic.to_h).not_to include(:deserializers)
      expect(share_topic.to_h).not_to include(:pause)
    end
  end

  context "with backwards-compatible flat aliases" do
    it "expect Routing::ConsumerGroup to alias ConsumerGroups::Group" do
      expect(Karafka::Routing::ConsumerGroup).to equal(Karafka::Routing::ConsumerGroups::Group)
    end

    it "expect Routing::Topic to alias ConsumerGroups::Topic" do
      expect(Karafka::Routing::Topic).to equal(Karafka::Routing::ConsumerGroups::Topic)
    end
  end

  context "when a share group and a consumer group are drawn together" do
    it "expect both to validate and coexist" do
      cclass = consumer_class

      expect do
        builder.draw do
          consumer_group "orders" do
            topic(:orders) { consumer cclass }
          end

          share_group "webhooks" do
            topic(:webhooks) { consumer cclass }
          end
        end
      end.not_to raise_error

      expect(builder.map(&:group_type)).to match_array(%i[consumer share])
    end
  end
end
