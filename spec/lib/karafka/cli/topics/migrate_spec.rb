# frozen_string_literal: true

RSpec.describe_current do
  subject(:migrate_topics) { described_class.new }

  describe "#call" do
    let(:topics_create) { instance_double(Karafka::Cli::Topics::Create, call: false) }
    let(:topics_repartition) { instance_double(Karafka::Cli::Topics::Repartition, call: false) }
    let(:topics_align) { instance_double(Karafka::Cli::Topics::Align, call: false) }

    before do
      allow(Karafka::Cli::Topics::Create).to receive(:new).and_return(topics_create)
      allow(Karafka::Cli::Topics::Repartition).to receive(:new).and_return(topics_repartition)
      allow(Karafka::Cli::Topics::Align).to receive(:new).and_return(topics_align)

      allow(migrate_topics).to receive(:wait) # Stubbing the wait method to prevent delays in tests
    end

    context "when no operations make changes" do
      it "returns false indicating no changes were applied" do
        expect(migrate_topics.call).to be_falsey
      end

      it "preserves no-argument phase construction" do
        migrate_topics.call

        expect(Karafka::Cli::Topics::Create).to have_received(:new).with(no_args)
        expect(Karafka::Cli::Topics::Repartition).to have_received(:new).with(no_args)
        expect(Karafka::Cli::Topics::Align).to have_received(:new).with(no_args)
      end

      context "with custom Kafka configuration" do
        let(:kafka) { { "bootstrap.servers": "other:9092" } }

        it "passes it to every migration phase" do
          described_class.new(kafka: kafka).call

          expect(Karafka::Cli::Topics::Create).to have_received(:new).with(kafka: kafka)
          expect(Karafka::Cli::Topics::Repartition).to have_received(:new).with(kafka: kafka)
          expect(Karafka::Cli::Topics::Align).to have_received(:new).with(kafka: kafka)
        end
      end
    end

    context "when only Create makes changes" do
      before do
        allow(topics_create).to receive(:call).and_return(true)
      end

      it "returns true and waits once" do
        expect(migrate_topics.call).to be_truthy
        expect(migrate_topics).to have_received(:wait).once
      end
    end

    context "when Create and Repartition make changes" do
      before do
        allow(topics_create).to receive(:call).and_return(true)
        allow(topics_repartition).to receive(:call).and_return(true)
      end

      it "returns true and waits twice" do
        expect(migrate_topics.call).to be_truthy
        expect(migrate_topics).to have_received(:wait).twice
      end
    end

    context "when all operations make changes" do
      before do
        allow(topics_create).to receive(:call).and_return(true)
        allow(topics_repartition).to receive(:call).and_return(true)
        allow(topics_align).to receive(:call).and_return(true)
      end

      it "returns true and waits twice (no wait after the last operation)" do
        expect(migrate_topics.call).to be_truthy
        expect(migrate_topics).to have_received(:wait).twice
      end
    end
  end
end
