# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#virtual_partitions' do
    context 'when we use virtual_partitions without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.virtual_partitions.active?).to be(false)
        expect(topic.virtual_partitions.partitioner).to be_nil
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
      end
    end

    context 'when we define partitioner only' do
      it 'expect to use proper active status' do
        topic.virtual_partitions(partitioner: ->(_) { rand })
        expect(topic.virtual_partitions.active?).to be(true)
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
      end
    end

    context 'when we define partitioner and max_partitions' do
      it 'expect to use proper active status' do
        topic.virtual_partitions(partitioner: ->(_) { rand }, max_partitions: 7)
        expect(topic.virtual_partitions.active?).to be(true)
        expect(topic.virtual_partitions.max_partitions).to eq(7)
      end
    end
  end

  describe '#virtual_partitions?' do
    context 'when active' do
      before { topic.virtual_partitions(partitioner: ->(_) { rand }) }

      it { expect(topic.virtual_partitions?).to be(true) }
    end

    context 'when not active' do
      before { topic.virtual_partitions(partitioner: nil) }

      it { expect(topic.virtual_partitions?).to be(false) }
    end
  end

  describe '#reducer' do
    subject(:reducer) { topic.virtual_partitions.reducer }

    before { allow(Karafka::App.config).to receive(:concurrency).and_return(concurrency) }

    context 'when using default reducer' do
      context 'when concurrency is set to 1' do
        let(:concurrency) { 1 }

        it 'expect to reduce all to one value' do
          reduced = Array.new(100) { |i| reducer.call(i) }

          expect(reduced.uniq.size).to eq(1)
        end

        it 'expect to also reduce and other random stuff to 1' do
          reduced = Array.new(100) { reducer.call(rand.to_s) }

          expect(reduced.uniq.size).to eq(1)
        end
      end

      context 'when concurrency is set to 5' do
        let(:concurrency) { 5 }

        it 'expect to reduce all to 5' do
          reduced = Array.new(5) { |i| reducer.call(i) }

          expect(reduced.uniq.size).to eq(5)
        end
      end

      # yes 10, not 11 because this is fast but not perfect, this is why we give an option to use
      # custom reducers
      context 'when concurrency is set to 11' do
        let(:concurrency) { 11 }

        it 'expect to reduce all numericals to 10' do
          reduced = Array.new(11) { |i| reducer.call(i) }

          expect(reduced.uniq.size).to eq(10)
        end
      end

      context 'when concurrency is set to 21' do
        let(:concurrency) { 21 }

        it 'expect to reduce all numericals to 17' do
          reduced = Array.new(21) { |i| reducer.call(i) }

          expect(reduced.uniq.size).to eq(17)
        end
      end
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:virtual_partitions]).to eq(topic.virtual_partitions.to_h) }
  end
end
