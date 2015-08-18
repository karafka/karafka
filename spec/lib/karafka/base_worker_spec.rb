require 'spec_helper'

RSpec.describe Karafka::BaseWorker do
  subject { described_class.new }
  let(:topic) { double }
  let(:event) { double }
  let(:router) { double }
  let(:controller) { double }
  let(:params) { [rand(1000).to_s, topic] }
  specify { expect(described_class).to be < SidekiqGlass::Worker }

  it { expect(described_class.timeout).to eq 300 }

  describe '#execute' do
    it 'executes perform controller method' do
      expect(topic).to receive(:to_sym).and_return(topic)
      expect(Karafka::Connection::Event).to receive(:new)
        .with(topic, params.first).once.and_return(event)
      expect(Karafka::Routing::Router).to receive(:new)
        .with(event).once.and_return(router)
      expect(router).to receive(:descendant_controller).once
        .and_return(controller)

      expect(controller).to receive(:perform)

      subject.execute(*params)
    end
  end
end
