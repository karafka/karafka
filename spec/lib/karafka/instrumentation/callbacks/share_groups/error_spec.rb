# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) { described_class.new(subscription_group_id, group_id, client_name) }

  let(:subscription_group_id) { SecureRandom.hex(6) }
  let(:group_id) { SecureRandom.hex(6) }
  let(:client_name) { SecureRandom.hex(6) }
  let(:monitor) { Karafka.monitor }
  let(:error) { StandardError.new("boom") }

  describe "#call" do
    let(:changed) { [] }

    before do
      monitor.subscribe("error.occurred") do |event|
        changed << event
      end

      callback.call(reported_client_name, error)
    end

    context "when the error refers to a different client" do
      let(:reported_client_name) { "other" }

      it "expect not to emit it" do
        expect(changed).to be_empty
      end
    end

    context "when the error refers to our client" do
      let(:reported_client_name) { client_name }

      it "expect to emit it with the share group id and librdkafka error type" do
        expect(changed.size).to eq(1)
        expect(changed.first[:error]).to eq(error)
        expect(changed.first[:type]).to eq("librdkafka.error")
        expect(changed.first[:group_id]).to eq(group_id)
      end
    end
  end
end
