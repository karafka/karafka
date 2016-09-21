RSpec.describe Karafka::Connection::TopicConsumer do
  let(:group) { rand.to_s }
  let(:topic) { rand.to_s }
  let(:route) do
    instance_double(
      Karafka::Routing::Route,
      group: group,
      topic: topic
    )
  end

  subject(:topic_consumer) { described_class.new(route) }

  describe '.new' do
    it 'just remembers route' do
      expect(topic_consumer.instance_variable_get(:@route)).to eq route
    end
  end

  describe '#stop' do
    it 'expect to stop consumer and remove it' do

    end
  end
end
