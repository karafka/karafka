# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#virtual_partitions' do
    context 'when we use virtual_partitions without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.virtual_partitions.active?).to be(false)
        expect(topic.virtual_partitions.partitioner).to be_nil
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
        expect(topic.virtual_partitions.distribution).to eq(:consistent)
      end
    end

    context 'when we define partitioner only' do
      it 'expect to use proper active status' do
        topic.virtual_partitions(partitioner: ->(_) { rand })
        expect(topic.virtual_partitions.active?).to be(true)
        expect(topic.virtual_partitions.max_partitions).to eq(Karafka::App.config.concurrency)
        expect(topic.virtual_partitions.distribution).to eq(:consistent)
      end
    end

    context 'when we define partitioner and max_partitions' do
      it 'expect to use proper active status' do
        topic.virtual_partitions(partitioner: ->(_) { rand }, max_partitions: 7)
        expect(topic.virtual_partitions.active?).to be(true)
        expect(topic.virtual_partitions.max_partitions).to eq(7)
        expect(topic.virtual_partitions.distribution).to eq(:consistent)
      end
    end

    context 'when we define distribution' do
      it 'expect to use balanced distribution' do
        topic.virtual_partitions(partitioner: ->(_) { rand }, distribution: :balanced)
        expect(topic.virtual_partitions.active?).to be(true)
        expect(topic.virtual_partitions.distribution).to eq(:balanced)
      end

      it 'expect to use consistent distribution' do
        topic.virtual_partitions(partitioner: ->(_) { rand }, distribution: :consistent)
        expect(topic.virtual_partitions.active?).to be(true)
        expect(topic.virtual_partitions.distribution).to eq(:consistent)
      end
    end

    context 'when using consistent distribution' do
      it 'uses Consistent distributor' do
        topic.virtual_partitions(
          max_partitions: 10,
          partitioner: ->(_msg) { rand(10) },
          distribution: :consistent
        )

        expect(topic.virtual_partitions.distributor).to be_a(
          Karafka::Pro::Processing::VirtualPartitions::Distributors::Consistent
        )
      end
    end

    context 'when using balanced distribution' do
      it 'uses Balanced distributor' do
        topic.virtual_partitions(
          max_partitions: 10,
          partitioner: ->(_msg) { rand(10) },
          distribution: :balanced
        )

        expect(topic.virtual_partitions.distributor).to be_a(
          Karafka::Pro::Processing::VirtualPartitions::Distributors::Balanced
        )
      end
    end

    context 'when distribution is not specified' do
      it 'uses Consistent distributor as default' do
        topic.virtual_partitions(
          max_partitions: 10,
          partitioner: ->(_msg) { rand(10) }
        )

        expect(topic.virtual_partitions.distributor).to be_a(
          Karafka::Pro::Processing::VirtualPartitions::Distributors::Consistent
        )
      end
    end

    context 'when distribution is invalid' do
      it 'raises an error' do
        expect do
          topic.virtual_partitions(
            max_partitions: 10,
            partitioner: ->(_msg) { rand(10) },
            distribution: :invalid
          ).distributor
        end.to raise_error(Karafka::Errors::UnsupportedCaseError)
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
