# frozen_string_literal: true

RSpec.describe_current do
  subject(:supervisor) { described_class.new }

  describe "#run" do
    context "when fork is not supported" do
      let(:process) { Karafka::App.config.internal.process }
      let(:monitor) { Karafka::App.config.monitor }

      before do
        allow(Process).to receive(:respond_to?).and_call_original
        allow(Process).to receive(:respond_to?).with(:fork).and_return(false)
        allow(Karafka.producer).to receive(:close)
        allow(Rdkafka::Bindings).to receive(:rd_kafka_global_init)
        allow(process).to receive(:on_sigint)
        allow(monitor).to receive(:instrument).and_call_original
      end

      it "raises an unsupported option error" do
        expect { supervisor.run }.to raise_error(Karafka::Errors::UnsupportedOptionError, /JRuby/)
      end

      it "does not close the producer or init librdkafka" do
        expect { supervisor.run }.to raise_error(Karafka::Errors::UnsupportedOptionError)

        expect(Karafka.producer).not_to have_received(:close)
        expect(Rdkafka::Bindings).not_to have_received(:rd_kafka_global_init)
      end

      it "does not trap signals or report an error" do
        expect { supervisor.run }.to raise_error(Karafka::Errors::UnsupportedOptionError)

        expect(process).not_to have_received(:on_sigint)
        expect(monitor).not_to have_received(:instrument).with("error.occurred", any_args)
      end
    end
  end
end
