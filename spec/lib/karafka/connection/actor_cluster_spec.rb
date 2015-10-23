require 'spec_helper'

RSpec.describe Karafka::Connection::ActorCluster do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end
    end
  end

  let(:controllers) { [controller] }

  subject { described_class.new(controllers).wrapped_object }

  describe '#fetch_loop' do
    let(:listener) { double }
    let(:listeners) { [listener] }
    let(:block) { -> {} }

    context 'when there is no errors (happy path)' do
      before do
        expect(subject)
          .to receive(:loop)
          .and_yield

        expect(subject)
          .to receive(:listeners)
          .and_return(listeners)

        expect(Karafka::App)
          .to receive(:running?)
          .and_return(running?)
      end

      context 'when we decide to stop the application' do
        let(:running?) { false }

        it 'should not start listening' do
          expect(listener)
            .not_to receive(:fetch)

          subject.fetch_loop(block)
        end
      end

      context 'when the application is running' do
        let(:running?) { true }

        it 'should start listening' do
          expect(listener)
            .to receive(:fetch)
            .with(block)

          subject.fetch_loop(block)
        end
      end
    end

    context 'when something wrong happens' do
      before do
        expect(subject)
          .to receive(:loop)
          .and_yield
          .exactly(2).times

        expect(subject)
          .to receive(:listeners)
          .and_return(listeners)
          .exactly(2).times

        expect(listener)
          .to receive(:fetch)
          .and_raise(StandardError)

        allow(Karafka::App)
          .to receive(:running?)
          .and_return(true, false)
      end

      it 'should log it and retry' do
        expect(Karafka.logger)
          .to receive(:error)
          .exactly(2).times

        subject.fetch_loop(block)
      end
    end
  end

  describe '#listeners' do
    let(:listener) { double }

    before do
      expect(Karafka::Connection::Listener)
        .to receive(:new)
        .with(controller)
        .and_return(listener)
    end

    it 'should create new listeners based on the controllers' do
      expect(subject.send(:listeners)).to eq [listener]
    end
  end
end
