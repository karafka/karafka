# frozen_string_literal: true

RSpec.describe Karafka::Consumers::Includer do
  subject(:includer) { described_class.new }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:consumer) { consumer_class.new(topic) }
  let(:features_scope) { Karafka::Consumers }
  let(:backends_scope) { Karafka::Backends }
  let(:topic) do
    build(
      :routing_topic,
      backend: backend,
      batch_consuming: batch_consuming,
      responder: responder
    )
  end

  describe 'inline with batch consuming' do
    let(:backend) { :inline }
    let(:batch_consuming) { true }
    let(:responder) { nil }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq false }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq false }
  end

  describe 'inline without batch consuming' do
    let(:backend) { :inline }
    let(:batch_consuming) { false }
    let(:responder) { nil }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq false }
  end

  describe 'inline with responder' do
    let(:backend) { :inline }
    let(:batch_consuming) { false }
    let(:responder) { Class.new }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq true }
  end
end
