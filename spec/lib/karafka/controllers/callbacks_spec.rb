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

  context 'when we want to use after_fetched callback' do
    describe '#call' do
      context 'when there are no callbacks' do
        it 'just schedules' do
          expect(base_consumer).to receive(:process)

          base_consumer.call
        end
      end
    end

    context 'when we have a block based after_fetched' do
      let(:backend) { :inline }

      context 'when it throws abort to halt' do
        subject(:base_consumer) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseConsumer) do
            include Karafka::Backends::Inline
            include described_scope

            after_fetched do
              throw(:abort)
            end

            def consume
              self
            end
          end.new
        end

        it 'does not consume' do
          expect(base_consumer).not_to receive(:consume)

          base_consumer.call
        end
      end

      context 'when it does not throw abort to halt' do
        subject(:base_consumer) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseConsumer) do
            include Karafka::Backends::Inline
            include described_scope

            after_fetched do
              true
            end

            def consume
              self
            end
          end.new
        end

        let(:params) { double }

        it 'executes' do
          expect(base_consumer).to receive(:process)
          base_consumer.call
        end
      end
    end

    context 'when we have a method based after_fetched' do
      let(:backend) { :inline }

      context 'when it throws abort to halt' do
        subject(:base_consumer) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseConsumer) do
            include described_scope

            after_fetched :method

            def consume
              self
            end

            def method
              throw(:abort)
            end
          end.new
        end

        it 'does not consume' do
          expect(base_consumer).not_to receive(:consume)

          base_consumer.call
        end
      end

      context 'when it does not return false' do
        subject(:base_consumer) do
          described_scope = described_class

          ClassBuilder.inherit(Karafka::BaseConsumer) do
            include Karafka::Backends::Inline
            include described_scope

            after_fetched :method

            def consume
              self
            end

            def method
              true
            end
          end.new
        end

        it 'schedules to a backend' do
          expect(base_consumer).to receive(:consume)

          base_consumer.call
        end
      end
    end
  end
end
