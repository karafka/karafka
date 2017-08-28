# frozen_string_literal: true

RSpec.describe Karafka::Controllers::Includer do
  subject(:includer) { described_class.new }

  let(:controller_class) { Class.new(Karafka::BaseController) }
  let(:scope) { Karafka::Controllers }
  let(:topic) do
    instance_double(
      Karafka::Routing::Topic,
      processing_backend: processing_backend,
      batch_processing: batch_processing,
      responder: responder
    )
  end

  before { controller_class.topic = topic }

  describe 'inline with batch processing' do
    let(:processing_backend) { :inline }
    let(:batch_processing) { true }
    let(:responder) { nil }

    it { expect(controller_class.include?(scope::InlineBackend)).to eq true }
    it { expect(controller_class.include?(scope::SidekiqBackend)).to eq false }
    it { expect(controller_class.include?(scope::SingleParams)).to eq false }
    it { expect(controller_class.include?(scope::Responders)).to eq false }
  end

  describe 'inline without batch processing' do
    let(:processing_backend) { :inline }
    let(:batch_processing) { false }
    let(:responder) { nil }

    it { expect(controller_class.include?(scope::InlineBackend)).to eq true }
    it { expect(controller_class.include?(scope::SidekiqBackend)).to eq false }
    it { expect(controller_class.include?(scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(scope::Responders)).to eq false }
  end

  describe 'inline with responder' do
    let(:processing_backend) { :inline }
    let(:batch_processing) { false }
    let(:responder) { Class.new }

    it { expect(controller_class.include?(scope::InlineBackend)).to eq true }
    it { expect(controller_class.include?(scope::SidekiqBackend)).to eq false }
    it { expect(controller_class.include?(scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(scope::Responders)).to eq true }
  end

  describe 'sidekiq with responder' do
    let(:processing_backend) { :sidekiq }
    let(:batch_processing) { false }
    let(:responder) { Class.new }

    it { expect(controller_class.include?(scope::InlineBackend)).to eq false }
    it { expect(controller_class.include?(scope::SidekiqBackend)).to eq true }
    it { expect(controller_class.include?(scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(scope::Responders)).to eq true }
  end
end
