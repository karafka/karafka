# frozen_string_literal: true

RSpec.describe Karafka::Patches::RubyKafka do
  subject(:consumer) { consumer_class.new }

  # It would be really heavy to test out kafka, so instead of that we just can
  # stub whole kafka consumer and just check that our behavior is as we expect
  let(:consumer_class) do
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
      let(:messages_consumer) do
        instance_double(Karafka::Connection::MessagesConsumer, stop: true)
      end

      before do
        allow(Karafka::App).to receive(:stopped?).and_return(true)
        Karafka::Persistence::MessagesConsumer.write(messages_consumer)
      end

      it 'expect to not yield the original block as it would process data when stopped' do
        expect { |block| consumer.consumer_loop(&block) }.not_to yield_control
      end

      it 'expect to stop the current thread messages consumer' do
        expect(messages_consumer).to receive(:stop)
        consumer.consumer_loop
      end
    end

    context 'when karafka is running' do
      it 'expect to yield the original base block' do
        expect { |block| consumer.consumer_loop(&block) }.to yield_control
      end
    end
  end
end
