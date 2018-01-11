# frozen_string_literal: true

RSpec.describe Karafka::Consumers::SingleParams do
  subject(:consumer) { consumer_class.new }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:params_batch) { [OpenStruct.new(value: {}.to_json)] }
  let(:topic) do
    instance_double(
      Karafka::Routing::Topic,
      id: rand.to_s,
      backend: :inline,
      batch_consuming: true,
      responder: nil,
      parser: Karafka::Parsers::Json
    )
  end

  before do
    consumer_class.include(described_class)
    consumer_class.topic = topic
    consumer.params_batch = params_batch
  end

  it 'expect to provide #params' do
    expect(consumer.send(:params)).to eq consumer.send(:params_batch).first
  end
end
