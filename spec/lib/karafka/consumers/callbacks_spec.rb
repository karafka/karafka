# frozen_string_literal: true

RSpec.describe Karafka::Consumers::Callbacks do
  subject(:base_consumer) { working_class.new }

  let(:topic_name) { "topic#{rand}" }
  let(:backend) { :inline }
  let(:responder_class) { nil }
  let(:consumer_group) { Karafka::Routing::ConsumerGroup.new(rand.to_s) }
  let(:topic) do
    topic = Karafka::Routing::Topic.new(topic_name, consumer_group)
    topic.consumer = Class.new(Karafka::BaseConsumer)
    topic.consumer.include described_class
    topic.backend = backend
    topic.responder = responder_class
    topic
  end
  let(:working_class) do
    described_scope = described_class

    ClassBuilder.inherit(Karafka::BaseConsumer) do
      include Karafka::Backends::Inline
      include Karafka::Consumers::Responders
      include described_scope

      def consume
        self
      end
    end
  end

  before { working_class.topic = topic }

  describe '#consume' do
    let(:working_class) { ClassBuilder.inherit(Karafka::BaseConsumer) }

    it { expect { base_consumer.send(:consume) }.to raise_error NotImplementedError }
  end

  context 'when we want to use after_fetch callback' do
    let(:verifier) { double }

    describe '#call' do
      context 'when there are no callbacks' do
        it 'just schedules' do
          expect(base_consumer).to receive(:process)

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
        end.new
      end

      it 'calls after_fetch callback and executes' do
        base_consumer.verifier = verifier
        expect(verifier).to receive(:verify)
        expect(base_consumer).to receive(:process)
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
        end.new
      end

      it 'calls after_fetch_method and executes' do
        base_consumer.verifier = verifier
        expect(verifier).to receive(:verify)
        expect(base_consumer).to receive(:process)

        base_consumer.call
      end
    end

    context 'when we want to get local state with after_fetch' do
      subject(:base_consumer) do
        described_scope = described_class

        ClassBuilder.inherit(Karafka::BaseConsumer) do
          include Karafka::Backends::Inline
          include described_scope

          attr_reader :instance_var

          after_fetch { @instance_var = 10 }

          def initialize
            @instance_var = 0
          end

          def consume
            self
          end
        end.new
      end

      it 'is possible to access local state' do
        expect(base_consumer).to receive(:process)
        base_consumer.call

        expect(base_consumer.instance_var).to eq 10
      end
    end
  end
end
