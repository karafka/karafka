require 'spec_helper'

RSpec.describe Karafka::Monitor do
  subject { described_class.instance }

  describe '#notice' do
    let(:options) { { rand => rand } }
    let(:caller_label) { 'block (3 levels) in <top (required)>' }

    it 'expect to log a proper info' do
      expect(Karafka.logger)
        .to receive(:info)
        .with("#{self.class}##{caller_label} with #{options}")

      subject.notice self.class, options
    end
  end

  describe '#notice_error' do
    let(:error) { StandardError }

    [
      Karafka::Connection::ActorCluster,
      Karafka::Connection::Consumer,
      Karafka::Connection::Listener,
      Karafka::Params::Params
    ].each do |caller_class|
      context "when caller class is #{caller_class}" do
        it 'expec to log with error' do
          expect(Karafka.logger)
            .not_to receive(:info)

          expect(Karafka.logger)
            .to receive(:error)
            .with(error)

          subject.notice_error(caller_class, error)
        end
      end
    end

    [
      Karafka::Runner
    ].each do |caller_class|
      context "when caller class is #{caller_class}" do
        it 'expec to log with fatal' do
          expect(Karafka.logger)
            .not_to receive(:info)

          expect(Karafka.logger)
            .to receive(:fatal)
            .with(error)

          subject.notice_error(caller_class, error)
        end
      end
    end

    context 'any other class' do
      it 'expec to log with info' do
        expect(Karafka.logger)
          .to receive(:info)
          .with(error)

        subject.notice_error(Karafka, error)
      end
    end
  end

  describe '#caller_label' do
    it { expect(subject.send(:caller_label)).to eq 'instance_exec' }
  end

  describe '#logger' do
    it 'expect to return logger' do
      expect(subject.send(:logger)).to eq Karafka.logger
    end
  end

  describe '#caller_exceptions_map' do
    it { expect(subject.send(:caller_exceptions_map).keys).to eq %i( error fatal ) }

    let(:error_callers) do
      [
        Karafka::Connection::ActorCluster,
        Karafka::Connection::Consumer,
        Karafka::Connection::Listener,
        Karafka::Params::Params
      ]
    end

    let(:fatal_callers) do
      [
        Karafka::Runner
      ]
    end

    it 'expect to have proper classes on error' do
      expect(subject.send(:caller_exceptions_map)[:error]).to eq error_callers
    end

    it 'expect to have proper classes on fatal' do
      expect(subject.send(:caller_exceptions_map)[:fatal]).to eq fatal_callers
    end
  end
end
