# frozen_string_literal: true

RSpec.describe Karafka::Controllers::SingleParams do
  subject(:controller) { controller_class.new }

  let(:controller_class) { Class.new(Karafka::BaseController) }
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
    controller_class.include(described_class)
    controller_class.topic = topic
    controller.params_batch = params_batch
  end

  it 'expect to provide #params' do
    expect(controller.send(:params)).to eq controller.send(:params_batch).first
  end
end
