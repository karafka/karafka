RSpec.describe Karafka::Connection::Message do
  let(:topic) { double }
  let(:content) { double }

  subject(:message) { described_class.new(topic, content) }

  describe '.initialize' do
    it 'stores both topic and content' do
      expect(message.topic).to eq topic.to_s
      expect(message.content).to eq content
    end
  end

  describe '#topic' do
    let(:prefix) { 'baz' }

    before do
      allow(Karafka::App)
        .to receive_message_chain(:config, :kafka, :topic_prefix)
        .and_return(prefix)
    end

    context 'with a topic prefix' do
      it 'adds the prefix to the topic' do
        expect(message.topic).to eql("#{prefix}#{topic}")
      end
    end

    context 'without a topic prefix' do
      let(:prefix) { nil }

      it 'does not change the topic' do
        expect(message.topic).to eql(topic.to_s)
      end
    end
  end
end
