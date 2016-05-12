require 'spec_helper'

RSpec.describe Karafka::Setup::Configurators::WaterDrop do
  specify { expect(described_class).to be < Karafka::Setup::Configurators::Base }

  let(:config) do
    double(
      max_concurrency: ::Karafka::App.config.max_concurrency,
      kafka: double(hosts: ::Karafka::App.config.kafka.hosts)
    )
  end
  subject { described_class.new(config) }

  describe '#setup' do
    it 'expect to assign waterdrop default configs' do
      subject.setup

      expect(WaterDrop.config.send_messages).to eq true
      expect(WaterDrop.config.connection_pool_size).to eq config.max_concurrency
      expect(WaterDrop.config.connection_pool_timeout).to eq 1
      expect(WaterDrop.config.kafka_hosts).to eq config.kafka.hosts
      expect(WaterDrop.config.raise_on_failure).to eq true
    end
  end
end
