# frozen_string_literal: true

RSpec.describe_current do
  subject(:app_class) { described_class }

  describe "#consumer_groups" do
    let(:builder) { described_class.config.internal.routing.builder }

    it "returns consumer_groups builder" do
      expect(app_class.consumer_groups).to eq builder
    end
  end

  describe "Karafka delegations" do
    %i[
      root
      env
    ].each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        before { allow(Karafka).to receive(delegation).and_return(return_value) }

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(app_class.public_send(delegation)).to eq return_value
          expect(Karafka).to have_received(delegation)
        end
      end
    end
  end

  describe "Karafka::Status delegations" do
    %i[
      run!
      running?
      stop!
      done?
    ].each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        before do
          allow(described_class.config.internal.status)
            .to receive(delegation)
            .and_return(return_value)
        end

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(app_class.public_send(delegation)).to eq return_value

          expect(described_class.config.internal.status).to have_received(delegation)
        end
      end
    end
  end

  describe "#declaratives" do
    it "returns a Declaratives::Builder" do
      expect(app_class.declaratives).to be_a(Karafka::Declaratives::Builder)
    end

    it "returns the same builder instance on repeated calls" do
      expect(app_class.declaratives).to equal(app_class.declaratives)
    end

    context "with standalone draw DSL" do
      before do
        app_class.declaratives.draw do
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
        topics = app_class.declaratives.topics
        expect(topics.size).to eq(2)
        names = topics.map(&:name)
        expect(names).to contain_exactly("orders", "events")
      end

      it "stores topic configuration correctly" do
        orders = app_class.declaratives.find_topic(:orders)
        expect(orders.partitions).to eq(10)
        expect(orders.replication_factor).to eq(3)
        expect(orders.details).to eq("retention.ms": 604_800_000)
      end
    end

    context "with draw + routes coexistence" do
      before do
        app_class.declaratives.draw do
          topic :standalone_topic do
            partitions 20
          end
        end

        app_class.routes.draw do
          topic :routed_topic do
            consumer Class.new(Karafka::BaseConsumer)
            config(partitions: 5, replication_factor: 2)
          end
        end
      end

      it "both topics are in the repository" do
        standalone = app_class.declaratives.find_topic(:standalone_topic)
        routed = app_class.declaratives.find_topic(:routed_topic)

        expect(standalone).not_to be_nil
        expect(routed).not_to be_nil
        expect(standalone.partitions).to eq(20)
        expect(routed.partitions).to eq(5)
      end
    end
  end

  describe "#subscription_groups" do
    context "when no routes are drawn" do
      it { expect(app_class.subscription_groups).to eq({}) }
    end
  end

  describe "#assignments" do
    let(:assignments) { rand }

    before do
      allow(Karafka::Instrumentation::AssignmentsTracker.instance)
        .to receive(:current)
        .and_return(assignments)
    end

    it "expect to delegate to the assignments tracker" do
      expect(app_class.assignments).to eq(assignments)
    end
  end
end
