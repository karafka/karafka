# frozen_string_literal: true

RSpec.describe Karafka::Connection::ConfigAdapter do
  let(:controller) { Karafka::BaseController }
  let(:topic) { rand.to_s }
  let(:route) do
    Karafka::Routing::Route.new.tap do |route|
      route.controller = controller
      route.topic = topic
    end
  end

  describe '#client' do
    pending
  end

  describe '#consumer' do
    subject(:config) { described_class.consumer(route) }

    let(:expected_keys) { (described_class::EDGE_CASES_MAP[:consumer] + %i[group_id]).sort }

    it 'expect not to have anything else than consumer specific options + group_id' do
      expect(config.keys.sort).to eq expected_keys
    end
  end

  describe '#consuming' do
    subject(:config) { described_class.consuming(route) }

    let(:expected_keys) { (described_class::EDGE_CASES_MAP[:consuming]).sort }

    it 'expect not to have anything else than consuming specific options' do
      expect(config.keys.sort).to eq expected_keys
    end
  end

  describe '#subscription' do
    subject(:config) { described_class.subscription(route) }

    let(:expected_keys) { (described_class::EDGE_CASES_MAP[:subscription]).sort }

    it 'expect not to have anything else than subscription specific options' do
      expect(config.last.keys.sort).to eq expected_keys
    end

    it { expect(config.first).to eq route.topic }
  end
end
