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
    let(:mapper) { nil }

    before do
      allow(Karafka::App)
        .to receive_message_chain(:config, :kafka, :topic_mapper)
        .and_return(mapper)
    end

    context 'with a topic mapper' do
      let(:mapper) { ->(topic_in) { "#{topic_in}cat" } }

      it 'adds the mapper to the topic' do
        expect(mapper).to receive(:call).with(topic.to_s).and_call_original
        expect(message.topic).to include('cat')
      end
    end

    context 'without a topic mapper' do
      it 'does not change the topic' do
        expect(message.topic).to eql(topic.to_s)
      end
    end

    context 'with a different type' do
      let(:mapper) { 'foobar' }

      it 'does not change the topic' do
        expect(message.topic).to eql(topic.to_s)
      end
    end
  end
end
