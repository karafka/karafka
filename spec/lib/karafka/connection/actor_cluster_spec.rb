require 'spec_helper'

RSpec.describe Karafka::Connection::ActorCluster do
  let(:controller) { ClassBuilder.inherit(Karafka::BaseController) }
  let(:controllers) { [controller] }

  subject(:actor_cluster) { described_class.new(controllers).wrapped_object }

  describe '#fetch_loop' do
    let(:listener) { double }
    let(:listeners) { [listener] }
    let(:block) { -> {} }

    context 'when there is no errors (happy path)' do
      before do
        expect(actor_cluster)
          .to receive(:loop)
          .and_yield

        expect(actor_cluster)
          .to receive(:listeners)
          .and_return(listeners)

        expect(Karafka::App)
          .to receive(:running?)
          .and_return(running?)
      end

      context 'when we decide to stop the application' do
        let(:running?) { false }

        it 'does not start listening' do
          expect(listener)
            .not_to receive(:fetch)

          actor_cluster.fetch_loop(block)
        end
      end

      context 'when the application is running' do
        let(:running?) { true }

        it 'starts listening' do
          expect(listener)
            .to receive(:fetch)
            .with(block)

          actor_cluster.fetch_loop(block)
        end
      end
    end

    context 'when something wrong happens' do
      before do
        expect(actor_cluster)
          .to receive(:loop)
          .and_yield
          .exactly(2).times

        expect(actor_cluster)
          .to receive(:listeners)
          .and_return(listeners)
          .exactly(3).times

        expect(listener)
          .to receive(:fetch)
          .and_raise(StandardError)

        expect(listener)
          .to receive(:close)

        allow(Karafka::App)
          .to receive(:running?)
          .and_return(true, false)
      end

      it 'notices it and retry' do
        expect(Karafka.monitor)
          .to receive(:notice_error)
          .with(described_class, StandardError)

        actor_cluster.fetch_loop(block)
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

    it 'creates new listeners based on the controllers' do
      expect(actor_cluster.send(:listeners)).to eq [listener]
    end
  end

  describe '#close' do
    let(:listener) { instance_double(Karafka::Connection::Listener) }

    before do
      expect(Karafka::Connection::Listener)
        .to receive(:new)
        .with(controller)
        .and_return(listener)
    end

    it 'expect to close all the listeners' do
      expect(listener).to receive(:close)

      actor_cluster.close
    end
  end
end
