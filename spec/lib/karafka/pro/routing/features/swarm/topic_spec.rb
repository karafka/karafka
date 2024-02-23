# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  let(:nodes) { [1, 2, 3] }
  before do
    allow(Karafka::App.config.swarm).to receive(:nodes).and_return(5)
    allow(Karafka::App.config.swarm).to receive(:node).and_return(OpenStruct.new(id: 2))
  end

  describe '#swarm' do
    it 'initializes with default nodes range when no argument is provided' do
      expect(topic.swarm.nodes).to eq(0...5)
    end

    it 'initializes with provided nodes when argument is given' do
      topic.swarm(nodes: nodes)
      expect(topic.swarm.nodes).to eq(nodes)
    end
  end

  describe '#swarm?' do
    it { expect(topic.swarm?).to be true }
  end

  describe '#active?' do
    context 'when the node is within the swarm nodes' do
      it 'returns true' do
        topic.swarm(nodes: nodes)
        expect(topic.active?).to be true
      end
    end

    context 'when the node is not within the swarm nodes' do
      before do
        allow(Karafka::App.config.swarm).to receive(:node).and_return(OpenStruct.new(id: 5))
      end

      it 'returns false' do
        topic.swarm(nodes: nodes)
        expect(topic.active?).to be false
      end
    end
  end

  describe '#to_h' do
    it 'includes swarm settings in the hash' do
      topic.swarm(nodes: nodes)
      expect(topic.to_h[:swarm][:nodes]).to eq(nodes)
    end
  end
end
