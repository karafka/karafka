# frozen_string_literal: true

RSpec.describe Karafka::Consumers::Includer do
  subject(:includer) { described_class.new }

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:consumer) { consumer_class.new(topic) }
  let(:features_scope) { Karafka::Consumers }
  let(:backends_scope) { Karafka::Backends }
  let(:consumer_group) { build(:routing_consumer_group, batch_fetching: batch_fetching) }
  let(:topic) do
    build(
      :routing_topic,
      backend: backend,
      batch_consuming: batch_consuming,
      responder: responder,
      consumer_group: consumer_group
    )
  end

  describe 'inline with batch consuming' do
    let(:backend) { :inline }
    let(:batch_consuming) { true }
    let(:batch_fetching) { false }
    let(:responder) { nil }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq false }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq false }
    it { expect(consumer.singleton_class.include?(features_scope::Metadata)).to eq false }
  end

  describe 'inline with batch fetching' do
    let(:backend) { :inline }
    let(:batch_consuming) { true }
    let(:batch_fetching) { true }
    let(:responder) { nil }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq false }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq false }
    it { expect(consumer.singleton_class.include?(features_scope::Metadata)).to eq true }
  end

  describe 'inline without batch consuming' do
    let(:backend) { :inline }
    let(:batch_consuming) { false }
    let(:responder) { nil }
    let(:batch_fetching) { false }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq false }
    it { expect(consumer.singleton_class.include?(features_scope::Metadata)).to eq false }
  end

  describe 'inline with responder' do
    let(:backend) { :inline }
    let(:batch_consuming) { false }
    let(:responder) { Class.new }
    let(:batch_fetching) { false }

    it { expect(consumer.singleton_class.include?(backends_scope::Inline)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::SingleParams)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::Responders)).to eq true }
    it { expect(consumer.singleton_class.include?(features_scope::Metadata)).to eq false }
  end
end
