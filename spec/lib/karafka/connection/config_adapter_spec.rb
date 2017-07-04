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
  end

  describe '#consumer' do
    subject(:config) { described_class.consumer(route) }

    let(:expected_keys) { (described_class::EDGE_CASES_MAP[:consumer] + %i[group_id]).sort }

    it 'expect not to have anything else than consumer specific options + group_id' do
      expect(config.keys.sort).to eq expected_keys
    end
  end

  describe '#consuming' do
    pending
  end

  describe '#subscription' do
    pending
  end
end
