require 'spec_helper'

RSpec.describe Karafka::Runner do
  subject { described_class.new }

  describe '#new' do
    it 'should have a consumer instance created' do
      expect(subject.instance_variable_get(:'@consumer')).to be_a Karafka::Connection::Consumer
    end

    it 'should have terminator instance created' do
      expect(subject.instance_variable_get(:'@terminator')).to be_a Karafka::Terminator
    end
  end

  describe '#run' do
    let (:terminator) { double }

    before do
      subject.instance_variable_set(:'@terminator', terminator)
      expect(subject)
        .to receive(:loop)
        .and_yield
    end

    context 'runner was not terminated' do
      before do
        expect(terminator)
          .to receive(:terminated?)
          .and_return(false)
      end

      it 'should fetch' do
        expect(subject)
          .to receive(:fetch)

        subject.run
      end
    end

    context 'runner was terminated' do
      before do
        expect(terminator)
          .to receive(:terminated?)
          .and_return(true)
      end

      it 'should not fetch' do
        expect(subject)
          .to_not receive(:fetch)

        subject.run
      end
    end
  end

  describe '#fetch' do
    let(:consumer) { double }
    let(:terminator) { double }

    before do
      subject.instance_variable_set(:'@consumer', consumer)
      subject.instance_variable_set(:'@terminator', terminator)
    end

    context 'when everything is ok' do
      it 'should fetch from the consumer without logs and catch signals' do
        expect(terminator)
          .to receive(:catch_signals)
          .and_yield

        expect(Karafka.logger)
          .not_to receive(:fatal)

        expect(consumer)
          .to receive(:fetch)

        subject.send(:fetch)
      end
    end

    context 'when we have a fatal error' do
      it 'should log this error' do
        expect(terminator)
          .to receive(:catch_signals)
          .and_yield

        expect(consumer)
          .to receive(:fetch)
          .and_raise(StandardError)

        subject.instance_variable_set(:'@consumer', consumer)

        expect(Karafka.logger)
          .to receive(:fatal)

        expect { subject.send(:fetch) }.not_to raise_error
      end
    end
  end
end
