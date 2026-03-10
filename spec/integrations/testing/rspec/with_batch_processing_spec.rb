# frozen_string_literal: true

# We should be able to use the testing library with batch processing,
# verifying that multiple messages in a batch are handled correctly.

setup_karafka
setup_testing(:rspec)

class BatchConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[0] << JSON.parse(message.raw_payload)
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer BatchConsumer
    end
  end
end

RSpec.describe BatchConsumer do
  subject(:consumer) { karafka.consumer_for(DT.topic) }

  it "processes all messages in the batch and preserves content" do
    batch_size = 10
    records = Array.new(batch_size) do |i|
      { id: i, value: SecureRandom.uuid }
    end

    records.each { |record| karafka.produce(record.to_json) }

    expect { consumer.consume }.to change { DT[0].size }.by(batch_size)

    records.each_with_index do |record, i|
      expect(DT[0][i]["id"]).to eq(record[:id])
      expect(DT[0][i]["value"]).to eq(record[:value])
    end
  end
end
