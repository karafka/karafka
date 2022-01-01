# frozen_string_literal: true

RSpec.describe_current do
  subject(:app_class) { described_class }

  describe '#consumer_groups' do
    let(:builder) { described_class.config.internal.routing_builder }

    it 'returns consumer_groups builder' do
      expect(app_class.consumer_groups).to eq builder
    end
  end

  describe 'Karafka delegations' do
    %i[
      root
      env
    ].each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        before { allow(Karafka).to receive(delegation).and_return(return_value) }

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(app_class.public_send(delegation)).to eq return_value
          expect(Karafka).to have_received(delegation)
        end
      end
    end
  end

  describe 'Karafka::Status delegations' do
    %i[
      run!
      running?
      stop!
    ].each do |delegation|
      describe "##{delegation}" do
        let(:return_value) { double }

        before do
          allow(described_class.config.internal.status)
            .to receive(delegation)
            .and_return(return_value)
        end

        it "expect to delegate #{delegation} method to Karafka module" do
          expect(app_class.public_send(delegation)).to eq return_value

          expect(described_class.config.internal.status).to have_received(delegation)
        end
      end
    end
  end
end
