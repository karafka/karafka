# frozen_string_literal: true

RSpec.describe_current do
  it { expect(described_class).to be < Karafka::Processing::Partitioner }

  subject(:partitioner) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:concurrency) { 1 }
  let(:coordinator) { build(:processing_coordinator_pro) }
  let(:topic) { subscription_group.topics.first }
  let(:messages) { Array.new(100) { build(:messages_message) } }

  before { ::Karafka::App.config.concurrency = concurrency }

  after { ::Karafka::App.config.concurrency = 1 }

  context 'when we do not use virtual partitions' do
    it 'expect to yield with 0 and input messages' do
      expect { |block| partitioner.call(topic.name, messages, coordinator, &block) }
        .to yield_with_args(0, messages)
    end
  end

  context 'when we use virtual partitions but we only use one thread' do
    before { topic.virtual_partitions(partitioner: ->(_) { rand }) }

    it 'expect to yield with 0 and input messages' do
      expect { |block| partitioner.call(topic.name, messages, coordinator, &block) }
        .to yield_with_args(0, messages)
    end
  end

  context 'when we use virtual partitions and we use many threads' do
    let(:concurrency) { 5 }
    let(:yielded) do
      yielded = []
      partitioner.call(topic.name, messages, coordinator) { |*args| yielded << args }
      yielded
    end

    before { topic.virtual_partitions(partitioner: ->(_) { rand }) }

    it 'expect to use all the threads' do
      expect(yielded.map(&:first).sort).to eq((0..4).to_a)
    end

    it 'expect to have unique messages in all the groups' do
      expect(yielded.map(&:last).reduce(:&)).to eq([])
    end

    it 'expect to maintain the order based on the offsets' do
      yielded.each do |_, messages|
        messages.each_slice(2) do |m1, m2|
          expect(m1.offset).to be < m2.offset if m2
        end
      end
    end

    it 'expect to have unique groups' do
      expect(yielded.map(&:first)).to eq(yielded.map(&:first).uniq)
    end
  end

  context 'when partitioner would create more partitions than threads' do
    let(:concurrency) { 5 }
    let(:yielded) do
      yielded = []
      partitioner.call(topic.name, messages, coordinator) { |*args| yielded << args }
      yielded
    end

    before { topic.virtual_partitions(partitioner: ->(_) { SecureRandom.hex(6) }) }

    it 'expect to use all the threads' do
      expect(yielded.map(&:first).sort).to eq((0..4).to_a)
    end

    it 'expect to have unique messages in all the groups' do
      expect(yielded.map(&:last).reduce(:&)).to eq([])
    end

    it 'expect to maintain the order based on the offsets' do
      yielded.each do |_, messages|
        messages.each_slice(2) do |m1, m2|
          expect(m1.offset).to be < m2.offset if m2
        end
      end
    end

    it 'expect to have unique groups' do
      expect(yielded.map(&:first)).to eq(yielded.map(&:first).uniq)
    end
  end
end
