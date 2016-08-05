require 'spec_helper'

RSpec.describe Karafka::Consumer do
  subject(:consumer) { described_class }

  describe '#run' do
    it 'expect to run fetch in synchronization' do
      expect(consumer.send(:semaphore)).to receive(:synchronize).and_yield
      expect(Karafka::App).to receive(:run!)
      expect(consumer.send(:fetcher)).to receive(:fetch)
      expect(Karafka::App).to receive(:stop!)
      consumer.run
    end
  end

  describe '#semaphore' do
    it 'expect to create a semaphore instance' do
      expect(consumer.send(:semaphore)).to be_a Mutex
    end

    it 'expect to cache the same semaphore instance' do
      instance = consumer.send(:semaphore)
      expect(consumer.send(:semaphore)).to eq instance
    end
  end

  describe '#fetcher' do
    it 'expect to create a fetcher instance' do
      expect(consumer.send(:fetcher)).to be_a Karafka::Fetcher
    end

    it 'expect to cache the same fetcher instance' do
      instance = consumer.send(:fetcher)
      expect(consumer.send(:fetcher)).to eq instance
    end
  end
end
