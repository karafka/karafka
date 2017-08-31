# frozen_string_literal: true

RSpec.describe Karafka::Backends::Sidekiq do
  subject(:controller) { controller_class.new }

  let(:controller_class) { Class.new(Karafka::BaseController) }
  let(:interchanger) { Karafka::Params::Interchanger }
  let(:params_batch) { [OpenStruct.new(value: rand.to_s)] }
  let(:interchanged_data) { params_batch }
  let(:topic) do
    instance_double(
      Karafka::Routing::Topic,
      id: rand.to_s,
      interchanger: interchanger,
      backend: :sidekiq,
      batch_processing: true,
      responder: nil,
      parser: nil,
      worker: Class.new(Karafka::BaseWorker)
    )
  end

  before do
    controller_class.include(described_class)
    controller_class.topic = topic
    controller.params_batch = params_batch

    expect(interchanger)
      .to receive(:load)
      .with(controller.params_batch.to_a)
      .and_return(interchanged_data)
  end

  it 'expect to schedule with sidekiq using interchanger' do
    expect(topic.worker).to receive(:perform_async)
      .with(topic.id, interchanged_data)
    controller.call
  end
end
