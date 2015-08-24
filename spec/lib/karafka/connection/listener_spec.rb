require 'spec_helper'

RSpec.describe Karafka::Connection::Listener do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform; end
    end
  end

  # It is a celluloid actor, so to spec it - we take the wrapped object
  subject { described_class.new(controller).wrapped_object }

  describe 'stop?' do
    context 'when we dont want to stop' do
      before do
        subject.instance_variable_set(:'@stop', false)
      end

      it { expect(subject.stop?).to eq false }
    end

    context 'when we want to stop' do
      before do
        subject.instance_variable_set(:'@stop', true)
      end

      it { expect(subject.stop?).to eq true }
    end
  end

  describe 'stop!' do
    before do
      subject.instance_variable_set(:'@stop', false)
    end

    it 'should switch stop? to true' do
      expect(subject.stop?).to eq false
      subject.stop!
      expect(subject.stop?).to eq true
    end
  end

  describe '#fetch_loop' do
    let(:action) { double }

    context 'when we want to stop the loop' do
      before do
        expect(subject)
          .to receive(:stop?)
          .and_return(true)
      end

      it 'should never fetch' do
        expect(subject)
          .not_to receive(:fetch)

        subject.fetch_loop(action)
      end
    end

    context 'when we dont want to stop the loop' do
      before do
        expect(subject)
          .to receive(:stop?)
          .and_return(false)
      end

      it 'should fetch' do
        expect(subject)
          .to receive(:fetch)

        expect(subject)
          .to receive(:loop)
          .and_yield

        subject.fetch_loop(action)
      end
    end
  end

  describe '#fetch' do
    let(:action) { double }

    described_class::IGNORED_ERRORS.each do |error|
      let(:proxy) { double }

      context "when #{error} happens" do
        it 'should close the consumer and not raise error' do
          expect(subject)
            .to receive(:consumer)
            .and_raise(error.new)

          expect { subject.send(:fetch, action) }.not_to raise_error
        end
      end
    end

    context 'when unexpected error occurs' do
      let(:error) { StandardError }

      it 'should close the consumer and raise error' do
        expect(subject)
          .to receive(:consumer)
          .and_return(proxy)
          .at_least(:once)

        expect(proxy)
          .to receive(:fetch_loop)
          .and_raise(error)

        expect { subject.send(:fetch, action) }.to raise_error(error)
      end
    end

    context 'when no errors occur' do
      let(:consumer) { double }
      let(:_partition) { double }
      let(:messages_bulk) { [incoming_message] }
      let(:incoming_message) { double }
      let(:internal_message) { double }

      it 'should yield for each incoming message' do
        expect(subject)
          .to receive(:consumer)
          .and_return(consumer)
          .at_least(:once)

        expect(consumer)
          .to receive(:fetch_loop)
          .and_yield(_partition, messages_bulk)

        expect(subject)
          .to receive(:message)
          .with(incoming_message)
          .and_return(internal_message)

        expect(action)
          .to receive(:call)
          .with(internal_message)

        subject.send(:fetch, action)
      end
    end
  end

  describe '#message' do
    let(:message) { double }
    let(:content) { rand }
    let(:incoming_message) { double(value: content) }

    it 'should create an message instance' do
      expect(Karafka::Connection::Message)
        .to receive(:new)
        .with(controller.topic, content)
        .and_return(message)

      expect(subject.send(:message, incoming_message)).to eq message
    end
  end

  describe '#consumer' do
    context 'when consumer is already created' do
      let(:consumer) { double }

      before do
        subject.instance_variable_set(:'@consumer', consumer)
      end

      it 'should just return it' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .never
        expect(subject.send(:consumer)).to eq consumer
      end
    end

    context 'when consumer is not yet created' do
      let(:consumer) { double }

      before do
        subject.instance_variable_set(:'@consumer', nil)
      end

      it 'should create an instance and return' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .with(
            controller.group.to_s,
            Karafka::App.config.kafka_hosts,
            Karafka::App.config.zookeeper_hosts,
            controller.topic.to_s
          )
          .and_return(consumer)

        expect(subject.send(:consumer)).to eq consumer
      end
    end
  end
end
