# frozen_string_literal: true

RSpec.describe Karafka::Backends::Inline do
  subject(:controller) { controller_class.new }

  let(:controller_class) { Class.new(Karafka::BaseController) }

  before { controller_class.include(described_class) }

  it 'expect to call' do
    expect(controller).to receive(:consume)
    controller.call
  end
end
