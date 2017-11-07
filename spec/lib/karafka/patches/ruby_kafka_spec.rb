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

  describe '#consumer_loop' do
    context 'when karafka app has stopped' do
      let(:consumer) do
        instance_double(Karafka::Connection::Consumer, stop: true)
      end

      before do
        allow(Karafka::App).to receive(:stopped?).and_return(true)
        Karafka::Persistence::Consumer.write(consumer)
      end

      it 'expect to not yield the original block as it would process data when stopped' do
        expect { |block| kafka_consumer.consumer_loop(&block) }.not_to yield_control
      end

      it 'expect to stop the current thread messages consumer' do
        expect(consumer).to receive(:stop)
        kafka_consumer.consumer_loop
      end
    end

    context 'when karafka is running' do
      it 'expect to yield the original base block' do
        expect { |block| kafka_consumer.consumer_loop(&block) }.to yield_control
      end
    end
  end
end
