require 'spec_helper'

RSpec.describe Karafka::Cli::Topics do
  let(:cli) { Karafka::Cli.new }
  subject { described_class.new(cli) }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe '#call' do
    let(:zookeeper_host) { double }
    let(:topics) { { children: [rand.to_s] } }

    before do
      Karafka::App.config.zookeeper.hosts.each do |host|
        expect(Zookeeper)
          .to receive(:new)
          .with(host)
          .and_return(zookeeper_host)
      end

      expect(zookeeper_host)
        .to receive(:get_children)
        .with(path: '/brokers/topics')
        .and_return(topics)
    end

    it 'expect to fetch all broker topics to zookeeper and print them' do
      topics[:children].each do |topic|
        expect(subject)
          .to receive(:puts)
          .with(topic)
      end

      subject.call
    end
  end
end
