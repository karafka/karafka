# frozen_string_literal: true

RSpec.describe_current do
  let(:bearer) { instance_double(Rdkafka::Consumer, name: "TestBearer") }
  let(:rd_config) { instance_double(Rdkafka::Config) }
  let(:token_refresh) { described_class.new(bearer) }
  let(:monitor) { Karafka::Instrumentation::Monitor.new }
  let(:previous_monitor) { Karafka::App.config.monitor }

  before do
    previous_monitor
    allow(monitor).to receive(:instrument)
    Karafka::App.config.monitor = monitor
  end

  after { Karafka::App.config.monitor = previous_monitor }

  describe "#call" do
    context "when the bearer name matches" do
      it "calls Karafka.monitor.instrument with correct parameters" do
        token_refresh.call(rd_config, "TestBearer")
        expect(monitor).to have_received(:instrument).with(
          "oauthbearer.token_refresh",
          bearer: bearer,
          caller: token_refresh
        )
      end
    end

    context "when the bearer name does not match" do
      it "does not call Karafka.monitor.instrument" do
        token_refresh.call(rd_config, "AnotherBearer")
        expect(monitor).not_to have_received(:instrument)
      end
    end

    context "when oauth bearer handler contains error" do
      let(:statistics) { { "name" => client_name } }
      let(:tracked_errors) { [] }

      before do
        allow(monitor).to receive(:instrument).and_call_original

        monitor.subscribe("oauthbearer.token_refresh") do
          raise
        end

        local_errors = tracked_errors

        monitor.subscribe("error.occurred") do |event|
          local_errors << event
        end
      end

      it "expect to contain in, notify and continue as we do not want to crash rdkafka" do
        expect { token_refresh.call(rd_config, "TestBearer") }.not_to raise_error
        expect(tracked_errors.size).to eq(1)
        expect(tracked_errors.first[:type]).to eq("callbacks.oauthbearer_token_refresh.error")
      end
    end
  end
end
