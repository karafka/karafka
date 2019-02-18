# frozen_string_literal: true

RSpec.describe Karafka::Consumers::Callbacks do
  subject(:base_consumer) { working_class.new(topic) }

  let(:backend) { :inline }
  let(:responder_class) { nil }
  let(:consumer_group) { Karafka::Routing::ConsumerGroup.new(rand.to_s) }
  let(:topic) { build(:routing_topic) }
  let(:verifier) { double }
  let(:working_class) do
    described_scope = described_class

    ClassBuilder.inherit(Karafka::BaseConsumer) do
      include Karafka::Backends::Inline
      include Karafka::Consumers::Responders
      include described_scope
      attr_accessor :verifier

      def consume
        self
      end

      def process
        verifier.process
      end
    end
  end

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(Karafka::BaseConsumer) }

    it { expect { base_consumer.send(:consume) }.to raise_error NotImplementedError }
  end

  context 'when we want to use after_fetch callback' do
    before { base_consumer.verifier = verifier }

    describe '#call' do
      context 'when there are no callbacks' do
        it 'just schedules' do
          expect(verifier).to receive(:process)

          base_consumer.call
        end
      end
    end

    context 'when we have a block based after_fetch' do
      subject(:base_consumer) do
        described_scope = described_class

        ClassBuilder.inherit(Karafka::BaseConsumer) do
          include Karafka::Backends::Inline
          include described_scope
          attr_accessor :verifier

          after_fetch do
            verifier.verify
          end

          def consume
            self
          end

          def process
            verifier.process
          end
        end.new(topic)
      end

      it 'calls after_fetch callback and executes' do
        expect(verifier).to receive(:verify)
        expect(verifier).to receive(:process)
        base_consumer.call
      end
    end

    context 'when we have a method based after_fetch' do
      subject(:base_consumer) do
        described_scope = described_class

        ClassBuilder.inherit(Karafka::BaseConsumer) do
          include Karafka::Backends::Inline
          include described_scope
          attr_accessor :verifier

          after_fetch :after_fetch_method

          def consume
            self
          end

          def after_fetch_method
            verifier.verify
          end

          def process
            verifier.process
          end
        end.new(topic)
      end

      it 'calls after_fetch_method and executes' do
        expect(verifier).to receive(:verify)
        expect(verifier).to receive(:process)

        base_consumer.call
      end
    end

    context 'when we want to get local state with after_fetch' do
      subject(:base_consumer) do
        described_scope = described_class

        ClassBuilder.inherit(Karafka::BaseConsumer) do
          include Karafka::Backends::Inline
          include described_scope

          attr_accessor :verifier
          attr_reader :instance_var

          after_fetch { @instance_var = 10 }

          def initialize
            @instance_var = 0
          end

          def consume
            self
          end

          def process
            verifier.process
          end
        end.new
      end

      it 'is possible to access local state' do
        expect(verifier).to receive(:process)
        base_consumer.call

        expect(base_consumer.instance_var).to eq 10
      end
    end
  end
end
