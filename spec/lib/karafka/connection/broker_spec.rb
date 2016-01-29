require 'spec_helper'

RSpec.describe Karafka::Connection::Broker do
  subject { described_class.new(json_data.to_json) }
  let(:json_data) do
    {
      'jmx_port' => 7203,
      'host' => '172.17.0.2',
      'version' => 1,
      'port' => 9092
    }
  end

  describe '#new' do
    it { expect { subject }.not_to raise_error }
  end

  describe '#host' do
    it { expect(subject.host).to eq "#{json_data['host']}:#{json_data['port']}" }
  end
end
