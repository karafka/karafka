# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) { described_class.new(subscription_group_id, group_id, client_name) }

  let(:subscription_group_id) { SecureRandom.hex(6) }
  let(:group_id) { SecureRandom.hex(6) }
  let(:client_name) { SecureRandom.hex(6) }
  let(:monitor) { Karafka.monitor }

  describe "#call" do
    let(:changed) { [] }

    before do
      monitor.subscribe("statistics.emitted") do |event|
        changed << event
      end

      callback.call(statistics)
    end

    context "when the statistics refer to a different client" do
      let(:statistics) { { "name" => "other" } }

      it "expect not to emit them" do
        expect(changed).to be_empty
      end
    end

    context "when the statistics refer to our client" do
      let(:statistics) { { "name" => client_name } }

      it "expect to emit decorated statistics with the share group id" do
        expect(changed.size).to eq(1)
        expect(changed.first[:group_id]).to eq(group_id)
        expect(changed.first[:consumer_group_id]).to eq(group_id)
        expect(changed.first[:subscription_group_id]).to eq(subscription_group_id)
        expect(changed.first[:statistics]).to be_a(Hash)
      end
    end
  end
end
