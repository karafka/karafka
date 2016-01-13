require 'spec_helper'

RSpec.describe Karafka::Cli do
  subject { described_class.new }

  describe '#topics' do
    let(:zookeeper_host) { double }
    let(:topics) { { children: [rand.to_s] } }

    before do
      Karafka::App.config.zookeeper_hosts.each do |host|
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

      subject.topics
    end
  end
end
