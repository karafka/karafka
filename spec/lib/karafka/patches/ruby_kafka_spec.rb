# frozen_string_literal: true

RSpec.describe Karafka::Patches::RubyKafka do
  subject(:kafka_consumer) { kafka_consumer_class.new(topic) }

  # It would be really heavy to test out kafka, so instead of that we just can
  # stub whole kafka consumer and just check that our behavior is as we expect
  let(:kafka_consumer_class) do
    klass = ClassBuilder.inherit(Karafka::BaseConsumer) do
      def consumer_loop
        yield
      end
    end

    klass.prepend described_class
    klass
  end

  describe '#consumer_loop' do
    let(:client) { instance_double(Karafka::Connection::Client, stop: true) }
    let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
    let(:consumer_instance) { Karafka::Persistence::Consumers.fetch(topic, 0) }
    let(:topic) { build(:routing_topic, consumer: consumer_class) }

    before do
      Karafka::Persistence::Client.write(client)
      Thread.current[:consumers]&.clear
    end

    after { Thread.current[:client] = nil }

    context 'when karafka app has stopping' do
      before { allow(Karafka::App).to receive(:stopping?).and_return(true) }

      it 'expect to not yield the original block as it would process data when stopping' do
        expect { |block| kafka_consumer.consumer_loop(&block) }.not_to yield_control
      end

      it 'expect to stop the current thread messages client' do
        expect(client).to receive(:stop)
        kafka_consumer.consumer_loop
      end

      context 'when there are consumer instances with before_stop callback' do
        let(:verifier_double) { double }

        let(:consumer_class) do
          ClassBuilder.inherit(Karafka::BaseConsumer) do
            include Karafka::Consumers::Callbacks

            before_stop { verifier.verify }
          end
        end

        it 'expect to run the callback and not yield control' do
          expect(consumer_instance).to receive(:verifier).and_return(verifier_double)
          expect(verifier_double).to receive(:verify)

          expect { |block| kafka_consumer.consumer_loop(&block) }.not_to yield_control
        end
      end
    end

    context 'when karafka is running' do
      before { allow(Karafka::App).to receive(:stopping?).and_return(false) }

      context 'when there are consumer instances without callbacks' do
        let(:consumer_class) do
          ClassBuilder.inherit(Karafka::BaseConsumer) do
          end
        end

        it 'expect to yield the original base block' do
          # Make sure Consumer cache contains the instance of our consumer
          consumer_instance

          expect { |block| kafka_consumer.consumer_loop(&block) }.to yield_control
        end
      end

      context 'when there are consumer instances with callbacks' do
        let(:verifier_double) { double }

        before { allow(consumer_instance).to receive(:verifier).and_return(verifier_double) }

        context 'when using before_poll callback' do
          let(:consumer_class) do
            ClassBuilder.inherit(Karafka::BaseConsumer) do
              include Karafka::Consumers::Callbacks

              before_poll do
                verifier.verify
              end
            end
          end

          it 'expect to run the callback and yield the original base block' do
            expect(verifier_double).to receive(:verify)
            expect(Karafka::App).to receive(:stopping?).and_return(false)

            expect { |block| kafka_consumer.consumer_loop(&block) }.to yield_control
          end
        end

        context 'when using after_poll callback' do
          let(:consumer_class) do
            ClassBuilder.inherit(Karafka::BaseConsumer) do
              include Karafka::Consumers::Callbacks

              after_poll do
                verifier.verify
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
