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
    it 'should start fetching and just sleep (rest will happen in celluloid actors)' do
      expect(subject)
        .to receive(:sleep)

      expect(subject)
        .to receive(:fetch)

      subject.run
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
