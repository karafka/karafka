require 'spec_helper'

RSpec.describe Karafka::Cli::Routes do
  let(:cli) { Karafka::Cli.new }
  subject(:routes_cli) { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:topic) { rand.to_s }

    KEYS = %i(
      group controller worker parser interchanger
    ).freeze

    KEYS.each do |key|
      let(key) { rand.to_s }
    end

    let(:route) do
      attrs = KEYS.each_with_object({}) { |key, hash| hash[key] = send(key) }

      instance_double(Karafka::Routing::Route, attrs.merge(topic: topic))
    end

    before do
      expect(routes_cli)
        .to receive(:routes)
        .and_return([route])
    end

    it 'expect to print routes' do
      expect(routes_cli)
        .to receive(:puts)
        .with("#{topic}:")

      KEYS.each do |key|
        expect(routes_cli)
          .to receive(:print)
          .with(key.to_s.capitalize, send(key))
      end

      routes_cli.call
    end
  end

  describe '#routes' do
    let(:route1) { Karafka::Routing::Route.new.tap { |route| route.topic = :b } }
    let(:route2) { Karafka::Routing::Route.new.tap { |route| route.topic = :a } }
    let(:karafka_routes) { [route1, route2] }

    before do
      expect(Karafka::App)
        .to receive(:routes)
        .and_return(karafka_routes)
    end

    it { expect(routes_cli.send(:routes)).to eq [route2, route1] }
  end

  describe '#print' do
    let(:label) { rand.to_s }
    let(:value) { rand.to_s }

    it 'expect to printf nicely' do
      expect(routes_cli)
        .to receive(:printf)
        .with("%-18s %s\n", "  - #{label}:", value)

      routes_cli.send(:print, label, value)
    end
  end
end
