# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) { described_class.new(subscription_group_id, group_id) }

  let(:subscription_group_id) { SecureRandom.hex(6) }
  let(:group_id) { SecureRandom.hex(6) }
  let(:offsets) { [{ topic: "topic", partition: 0, offsets: [1, 2] }] }
  let(:error) { Rdkafka::RdkafkaError.new(121) }
  let(:events) { [] }

  before do
    Karafka.monitor.subscribe("error.occurred") do |event|
      events << event if event[:subscription_group_id] == subscription_group_id
    end
  end

  context "when the acknowledgements were accepted" do
    before { callback.call(offsets, nil) }

    it { expect(events).to be_empty }
  end

  context "when the acknowledgements were rejected" do
    before { callback.call(offsets, error) }

    it "expect to report them as an error with the rejected offsets" do
      expect(events.size).to eq(1)

      event = events.first

      expect(event[:type]).to eq("connection.client.acknowledgement.error")
      expect(event[:error]).to eq(error)
      expect(event[:offsets]).to eq(offsets)
      expect(event[:group_id]).to eq(group_id)
      expect(event[:caller]).to eq(callback)
    end
  end
end
