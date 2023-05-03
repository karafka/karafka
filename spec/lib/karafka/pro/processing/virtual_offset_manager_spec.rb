# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new(topic, partition) }

  let(:topic) { rand.to_s }
  let(:partition) { rand(100) }

  context 'when having a regular linear marking flow on one group' do
    let(:range) { (0..9).to_a }

    before do
      manager.register(range)
      range.each { |offset| manager.mark(OpenStruct.new(offset: offset)) }
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(9) }
    it { expect(manager.marked).to eq(range) }
  end

  context 'when having a reverse linear marking flow on one group' do
    let(:range) { (0..9).to_a }

    before do
      manager.register(range)
      range.reverse_each { |offset| manager.mark(OpenStruct.new(offset: offset)) }
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(9) }
    it { expect(manager.marked).to eq(range) }
  end

  context 'when having a reverse linear marking flow on one group except last' do
    let(:range) { (0..9).to_a }

    before do
      manager.register(range)
      range[1..].reverse_each { |offset| manager.mark(OpenStruct.new(offset: offset)) }
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(9) }
    it { expect(manager.marked).to eq(range) }
  end

  context 'when having last markable on one group' do
    let(:range) { (0..9).to_a }

    before do
      manager.register(range)
      manager.mark(OpenStruct.new(offset: 9))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(9) }
    it { expect(manager.marked).to eq(range) }
  end

  context 'when not marking at all' do
    let(:range) { (0..9).to_a }

    before { manager.register(range) }

    it { expect(manager.markable?).to eq(false) }
    it { expect { manager.markable }.to raise_error(Karafka::Errors::InvalidRealOffsetUsage) }
    it { expect(manager.marked).to eq([]) }
  end

  context 'when marking first on one group' do
    let(:range) { (0..9).to_a }

    before do
      manager.register(range)
      manager.mark(OpenStruct.new(offset: 0))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(0) }
    it { expect(manager.marked).to eq([0]) }
  end

  context 'when marking from previous group' do
    before do
      range = (10..19).to_a
      manager.register(range)
      manager.mark(OpenStruct.new(offset: 5))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(5) }
    it { expect(manager.marked).to eq([5]) }
  end

  context 'when having multi-group full linear marking' do
    let(:range) { (0..19).to_a }

    before do
      manager.register(range.select(&:odd?))
      manager.register(range.reject(&:odd?))

      range.each { |offset| manager.mark(OpenStruct.new(offset: offset)) }
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(19) }
    it { expect(manager.marked).to eq(range) }
  end

  context 'when having multi-group first even middle marking' do
    let(:range) { (0..19).to_a }

    before do
      manager.register(range.select(&:odd?))
      manager.register(range.reject(&:odd?))

      manager.mark(OpenStruct.new(offset: 10))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(0) }
    it { expect(manager.marked).to eq([0, 2, 4, 6, 8, 10]) }
  end

  context 'when having multi-group first odd middle marking' do
    before do
      range = (0..19).to_a
      manager.register(range.select(&:odd?))
      manager.register(range.reject(&:odd?))

      manager.mark(OpenStruct.new(offset: 9))
    end

    it { expect(manager.markable?).to eq(false) }
    it { expect { manager.markable }.to raise_error(Karafka::Errors::InvalidRealOffsetUsage) }
    it { expect(manager.marked).to eq([1, 3, 5, 7, 9]) }
  end

  context 'when marking some from many case 1' do
    before do
      range = (0..19).to_a
      manager.register(range.select(&:odd?))
      manager.register(range.reject(&:odd?))

      manager.mark(OpenStruct.new(offset: 3))
      manager.mark(OpenStruct.new(offset: 12))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(4) }
    it { expect(manager.marked).to eq([0, 1, 2, 3, 4, 6, 8, 10, 12]) }
  end

  context 'when marking some from many case 2' do
    before do
      range = (0..19).to_a
      manager.register(range.select(&:odd?))
      manager.register(range.reject(&:odd?))

      manager.mark(OpenStruct.new(offset: 13))
    end

    it { expect(manager.markable?).to eq(false) }
    it { expect { manager.markable }.to raise_error(Karafka::Errors::InvalidRealOffsetUsage) }
    it { expect(manager.marked).to eq([1, 3, 5, 7, 9, 11, 13]) }
  end

  context 'when marking until' do
    let(:range) { (0..19).to_a }

    before do
      manager.register(range.select(&:odd?))
      manager.register(range.reject(&:odd?))

      manager.mark_until(OpenStruct.new(offset: 10))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(10) }
    it { expect(manager.marked).to eq((0..10).to_a) }
  end

  context 'when marking first one higher than first offset' do
    before do
      manager.register([3, 4, 5, 6])
      manager.register([7, 8, 9, 10])

      manager.mark(OpenStruct.new(offset: 10))
    end

    it { expect(manager.markable?).to eq(true) }
    it { expect(manager.markable.offset).to eq(2) }
    it { expect(manager.marked).to eq([7, 8, 9, 10]) }
  end

  context 'when marking higher than start on 0' do
    before do
      manager.register([0, 1, 2, 4, 5, 6])
      manager.register([7, 8, 9, 10])

      manager.mark(OpenStruct.new(offset: 10))
    end

    it { expect(manager.markable?).to eq(false) }
    it { expect { manager.markable }.to raise_error(Karafka::Errors::InvalidRealOffsetUsage) }
    it { expect(manager.marked).to eq([7, 8, 9, 10]) }
  end
end
