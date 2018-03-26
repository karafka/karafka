# frozen_string_literal: true

RSpec.describe Karafka::Patches::RubyKafka do
  subject(:kafka_consumer) { kafka_consumer_class.new }

  # It would be really heavy to test out kafka, so instead of that we just can
  # stub whole kafka consumer and just check that our behavior is as we expect
  let(:kafka_consumer_class) do
    klass = ClassBuilder.build do
      def consumer_loop
        yield
      end
    end

    klass.prepend described_class
    klass
  end

  before { Karafka::Persistence::Consumer.clear }

  describe '#consumer_loop' do
    let(:client) { instance_double(Karafka::Connection::Client, stop: true) }
    let(:topic) { instance_double(Karafka::Routing::Topic, id: rand.to_s, persistent: false) }

    before { Karafka::Persistence::Client.write(client) }

    after { Thread.current[:client] = nil }

    context 'when karafka app has stopped' do
      before { allow(Karafka::App).to receive(:stopped?).and_return(true) }

      it 'expect to not yield the original block as it would process data when stopped' do
        expect { |block| kafka_consumer.consumer_loop(&block) }.not_to yield_control
      end

      it 'expect to stop the current thread messages client' do
        expect(client).to receive(:stop)
        kafka_consumer.consumer_loop
      end

      context 'and there are consumer instances with before_stop callback' do
        let(:verifier_double) { double }

        let(:consumer) do
          ClassBuilder.inherit(Karafka::BaseConsumer) do
            include Karafka::Consumers::Callbacks

            before_stop do
              self.class.verifier.verify
            end
          end
        end

        before do
          Karafka::Persistence::Consumer.fetch(
            instance_double(Karafka::Routing::Topic, consumer: consumer, persistent: true),
            0
          )

          allow(consumer).to receive(:verifier).and_return(verifier_double)
        end

        it 'expect to run the callback and not yield control' do
          expect(verifier_double).to receive(:verify)

          expect { |block| kafka_consumer.consumer_loop(&block) }.not_to yield_control
        end
      end
    end

    context 'when karafka is running' do
      before { allow(Karafka::App).to receive(:stopped?).and_return(false) }

      it 'expect to yield the original base block' do
        expect { |block| kafka_consumer.consumer_loop(&block) }.to yield_control
      end

      context 'and there are consumer instances with callbacks' do
        let(:verifier_double) { double }

        before do
          Karafka::Persistence::Consumer.fetch(
            instance_double(Karafka::Routing::Topic, consumer: consumer, persistent: true),
            0
          )

          allow(consumer).to receive(:verifier).and_return(verifier_double)
        end

        context 'for before_poll callback' do
          let(:consumer) do
            ClassBuilder.inherit(Karafka::BaseConsumer) do
              include Karafka::Consumers::Callbacks

              before_poll do
                self.class.verifier.verify
              end
            end
          end

          it 'expect to run the callback and yield the original base block' do
            expect(verifier_double).to receive(:verify)

            expect { |block| kafka_consumer.consumer_loop(&block) }.to yield_control
          end
        end

        context 'for after_poll callback' do
          let(:consumer) do
            ClassBuilder.inherit(Karafka::BaseConsumer) do
              include Karafka::Consumers::Callbacks

              after_poll do
                self.class.verifier.verify
              end
            end
          end

          it 'expect to run the callback and yield the original base block' do
            expect(verifier_double).to receive(:verify)

            expect { |block| kafka_consumer.consumer_loop(&block) }.to yield_control
          end
        end
      end
    end
  end
end
