RSpec.describe Karafka::Connection::Message do
  let(:topic) { double }
  let(:content) { double }

  subject(:message) { described_class.new(topic, content) }

  describe '.initialize' do
    it 'stores both topic and content' do
      expect(message.topic).to eq topic
      expect(message.content).to eq content
    end
  end
end
