# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) { described_class.new(subscription_group, client_id) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:consumer_group_id) { subscription_group.group.id }
  let(:client_id) { rand.to_s }
  let(:tpl) { rand }
  let(:monitor) { Karafka::Instrumentation::Monitor.new }
  let(:previous_monitor) { Karafka::App.config.monitor }
  let(:tracked_errors) { [] }

  before do
    previous_monitor
    Karafka::App.config.monitor = monitor

    local_errors = tracked_errors

    monitor.subscribe("error.occurred") do |event|
      local_errors << event
    end
  end

  after { Karafka::App.config.monitor = previous_monitor }

  describe "#on_offsets_commit_failed" do
    context "when the commit failed" do
      let(:error) { Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL) }

      before { callback.on_offsets_commit_failed(error, tpl) }

      it "expect to publish the error with the commit details" do
        expect(tracked_errors.size).to eq(1)
        expect(tracked_errors.first.payload).to eq(
          caller: callback,
          subscription_group_id: subscription_group.id,
          consumer_group_id: consumer_group_id,
          group_id: consumer_group_id,
          client_id: client_id,
          type: "connection.client.commit_offsets.error",
          error: error,
          tpl: tpl
        )
      end
    end

    Karafka::Connection::Proxy::COMMIT_HANDLED_ERRORS.each do |code|
      context "when the commit failed with #{code} that the proxy handles without raising" do
        let(:error) { instance_double(Rdkafka::RdkafkaError, code: code) }

        before { callback.on_offsets_commit_failed(error, tpl) }

        it { expect(tracked_errors).to be_empty }
      end
    end

    context "when an error.occurred subscriber fails on the commit error" do
      before do
        monitor.subscribe("error.occurred") do |event|
          raise StandardError if event[:type] == "connection.client.commit_offsets.error"
        end
      end

      it "expect to contain in, notify and continue as we do not want to crash rdkafka" do
        error = Rdkafka::RdkafkaError.new(Rdkafka::Bindings::RD_KAFKA_RESP_ERR__FATAL)

        expect { callback.on_offsets_commit_failed(error, tpl) }
          .not_to raise_error
        expect(tracked_errors.last[:type]).to eq("callbacks.offset_commit.error")
      end
    end
  end
end
