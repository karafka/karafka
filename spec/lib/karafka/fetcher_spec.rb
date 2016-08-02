require 'spec_helper'

RSpec.describe Karafka::Fetcher do
  subject { described_class.new }

  describe '#fetch_loop' do
    it 'expect to consume with fetch_loop' do
      expect(subject)
        .to receive(:consume_with)
        .with(:fetch_loop)

      subject.fetch_loop
    end
  end

  describe '#fetch' do
    it 'expect to consume with fetch' do
      expect(subject)
        .to receive(:consume_with)
        .with(:fetch)

      subject.fetch
    end
  end

  describe '#consume_with' do
    let(:execution_method) { %i(fetch_loop fetch).sample }

    context 'when everything is ok' do
      let(:future) { instance_double(Celluloid::Future, value: rand) }
      let(:actor_clusters) { [actor_cluster] }
      let(:consumer) { -> {} }
      let(:async_scope) { actor_cluster }
      let(:actor_cluster) do
        instance_double(
          Karafka::Connection::ActorCluster,
          execution_method => future,
          terminate: true
        )
      end

      before do
        allow(subject)
          .to receive(:actor_clusters)
          .and_return(actor_clusters)

        expect(subject)
          .to receive(:consumer)
          .and_return(consumer)
      end

      it 'starts asynchronously consumption for each actor_cluster' do
        expect(actor_cluster)
          .to receive(:future)
          .and_return(async_scope)

        subject.send(:consume_with, execution_method)
      end
    end

    context 'when something goes wrong internaly' do
      let(:error) { StandardError }

      before do
        expect(subject)
          .to receive(:actor_clusters)
          .and_raise(error)
      end

      it 'stops the app and reraise' do
        expect(Karafka::App)
          .to receive(:stop!)

        expect(Karafka.monitor)
          .to receive(:notice_error)
          .with(described_class, error)

        expect { subject.send(:consume_with, execution_method) }.to raise_error(error)
      end
    end
  end

  describe '#actor_clusters' do
    let(:route) { double }
    let(:routes) { [route] }

    before do
      expect(Karafka::App)
        .to receive(:routes)
        .and_return(routes)

      expect(subject)
        .to receive(:slice_size)
        .and_return(rand(1000) + 1)

      expect(Karafka::Connection::ActorCluster)
        .to receive(:new)
        .with(routes)
    end

    it { expect(subject.send(:actor_clusters)).to be_a Array }
  end

  describe '#consumer' do
    let(:subject) { described_class.new.send(:consumer) }

    it 'is a proc' do
      expect(subject).to be_a Proc
    end

    context 'when we invoke a consumer block' do
      let(:message) { double }
      let(:consumer) { Karafka::Connection::Consumer.new }

      before do
        expect(Karafka::Connection::Consumer)
          .to receive(:new)
          .and_return(consumer)
      end

      it 'consumes the message' do
        expect(consumer)
          .to receive(:consume)
          .with(message)

        subject.call(message)
      end
    end
  end

  describe '#slice_size' do
    subject { described_class.new.send(:slice_size) }

    let(:config) { double }

    before do
      expect(Karafka::App)
        .to receive(:routes)
        .and_return(Array.new(controllers_length))

      expect(Karafka::App)
        .to receive(:config)
        .and_return(config)

      expect(config)
        .to receive(:max_concurrency)
        .and_return(max_concurrency)
    end

    context 'when there are no controllers' do
      let(:controllers_length) { 0 }
      let(:max_concurrency) { 100 }

      it { expect(subject).to eq 1 }
    end

    context 'when we have less controllers than max_concurrency level' do
      let(:controllers_length) { 1 }
      let(:max_concurrency) { 20 }

      it { expect(subject).to eq 1 }
    end

    context 'when we have more controllers than max_concurrency level' do
      let(:controllers_length) { 110 }
      let(:max_concurrency) { 20 }

      it { expect(subject).to eq 5 }
    end

    context 'when we have the same amount of controllers and max_concurrency level' do
      let(:controllers_length) { 20 }
      let(:max_concurrency) { 20 }

      it { expect(subject).to eq 1 }
    end
  end
end
