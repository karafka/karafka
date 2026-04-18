# frozen_string_literal: true

RSpec.describe "Karafka::App.declaratives integration" do
  describe "Karafka::App.declaratives" do
    it "returns a Declaratives::Builder" do
      expect(Karafka::App.declaratives).to be_a(Karafka::Declaratives::Builder)
    end

    it "returns the same builder instance on repeated calls" do
      expect(Karafka::App.declaratives).to equal(Karafka::App.declaratives)
    end
  end

  describe "standalone draw DSL" do
    before do
      Karafka::App.declaratives.draw do
        topic :orders do
          partitions 10
          replication_factor 3
          config "retention.ms" => 604_800_000
        end

        topic :events do
          partitions 50
        end
      end
    end

    it "creates topic declarations" do
      topics = Karafka::App.declaratives.topics
      expect(topics.size).to eq(2)
      names = topics.map(&:name)
      expect(names).to contain_exactly("orders", "events")
    end

    it "stores topic configuration correctly" do
      orders = Karafka::App.declaratives.find_topic(:orders)
      expect(orders.partitions).to eq(10)
      expect(orders.replication_factor).to eq(3)
      expect(orders.details).to eq("retention.ms": 604_800_000)
    end
  end

  describe "draw + routes coexistence" do
    before do
      Karafka::App.declaratives.draw do
        topic :standalone_topic do
          partitions 20
        end
      end

      Karafka::App.routes.draw do
        topic :routed_topic do
          consumer Class.new(Karafka::BaseConsumer)
          config(partitions: 5, replication_factor: 2)
        end
      end
    end

    it "both topics are in the repository" do
      standalone = Karafka::App.declaratives.find_topic(:standalone_topic)
      routed = Karafka::App.declaratives.find_topic(:routed_topic)

      expect(standalone).not_to be_nil
      expect(routed).not_to be_nil
      expect(standalone.partitions).to eq(20)
      expect(routed.partitions).to eq(5)
    end
  end
end
