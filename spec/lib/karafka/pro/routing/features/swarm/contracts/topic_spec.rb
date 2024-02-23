# frozen_string_literal: true

RSpec.describe_current do
  subject(:validation) { described_class.new.call(config) }

  let(:config) do
    {
      swarm: {
        active: true,
        nodes: nodes
      }
    }
  end

  context 'when configuration is valid' do
    let(:nodes) { 0...Karafka::App.config.swarm.nodes }

    it 'passes validation' do
      expect(validation).to be_success
    end
  end

  context 'when active is not true' do
    let(:nodes) { 0...Karafka::App.config.swarm.nodes }

    before { config[:swarm][:active] = false }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes is not a Range or Array of Integers' do
    let(:nodes) { %w[invalid nodes] }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when nodes array contains non-integer values' do
    let(:nodes) { [1, 'two', 3] }

    it 'fails validation' do
      expect(validation).not_to be_success
    end
  end

  context 'when range of nodes does not match any existing node' do
    let(:nodes) { 100...200 }

    it 'fails validation due to non-existent nodes' do
      expect(validation).not_to be_success
    end
  end

  context 'with valid range fitting number of nodes' do
    let(:nodes) { 0...2 }

    it 'passes validation' do
      expect(validation).to be_success
    end
  end

  context 'with an infinite range' do
    let(:nodes) { 0...Float::INFINITY }

    it 'passes validation' do
      expect(validation).to be_success
    end
  end
end
