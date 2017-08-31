# frozen_string_literal: true

RSpec.describe Karafka::Controllers::Includer do
  subject(:includer) { described_class.new }

  let(:controller_class) { Class.new(Karafka::BaseController) }
  let(:features_scope) { Karafka::Controllers }
  let(:backends_scope) { Karafka::Backends }
  let(:topic) do
    instance_double(
      Karafka::Routing::Topic,
      backend: backend,
      batch_processing: batch_processing,
      responder: responder
    )
  end

  before { controller_class.topic = topic }

  describe 'inline with batch processing' do
    let(:backend) { :inline }
    let(:batch_processing) { true }
    let(:responder) { nil }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq true }
    it { expect(controller_class.include?(backends_scope::Sidekiq)).to eq false }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq false }
    it { expect(controller_class.include?(features_scope::Responders)).to eq false }
  end

  describe 'inline without batch processing' do
    let(:backend) { :inline }
    let(:batch_processing) { false }
    let(:responder) { nil }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq true }
    it { expect(controller_class.include?(backends_scope::Sidekiq)).to eq false }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(features_scope::Responders)).to eq false }
  end

  describe 'inline with responder' do
    let(:backend) { :inline }
    let(:batch_processing) { false }
    let(:responder) { Class.new }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq true }
    it { expect(controller_class.include?(backends_scope::Sidekiq)).to eq false }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(features_scope::Responders)).to eq true }
  end

  describe 'sidekiq with responder' do
    let(:backend) { :sidekiq }
    let(:batch_processing) { false }
    let(:responder) { Class.new }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq false }
    it { expect(controller_class.include?(backends_scope::Sidekiq)).to eq true }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(features_scope::Responders)).to eq true }
  end
end
