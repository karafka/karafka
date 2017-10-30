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
      batch_consuming: batch_consuming,
      responder: responder
    )
  end

  before { controller_class.topic = topic }

  describe 'inline with batch consuming' do
    let(:backend) { :inline }
    let(:batch_consuming) { true }
    let(:responder) { nil }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq true }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq false }
    it { expect(controller_class.include?(features_scope::Responders)).to eq false }
  end

  describe 'inline without batch consuming' do
    let(:backend) { :inline }
    let(:batch_consuming) { false }
    let(:responder) { nil }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq true }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(features_scope::Responders)).to eq false }
  end

  describe 'inline with responder' do
    let(:backend) { :inline }
    let(:batch_consuming) { false }
    let(:responder) { Class.new }

    it { expect(controller_class.include?(backends_scope::Inline)).to eq true }
    it { expect(controller_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(controller_class.include?(features_scope::Responders)).to eq true }
  end
end
