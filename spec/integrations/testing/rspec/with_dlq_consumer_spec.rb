# frozen_string_literal: true

# We should be able to use the testing library with DLQ-configured topics
# and verify that normal consumer processing works with DLQ routing configured.

setup_karafka
setup_testing(:rspec)

class DlqTestConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      payload = JSON.parse(message.raw_payload)

      raise StandardError, "Bad record" if payload["fail"]

      DT[0] << payload
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer DlqTestConsumer
      dead_letter_queue topic: DT.topics[1]
    end
  end
end

RSpec.describe DlqTestConsumer do
  subject(:consumer) { karafka.consumer_for(DT.topic) }

  it "processes valid messages with DLQ routing configured" do
    karafka.produce({ id: 1, value: "good" }.to_json)
    karafka.produce({ id: 2, value: "also good" }.to_json)

    expect { consumer.consume }.to change { DT[0].size }.by(2)
    expect(DT[0].first["id"]).to eq(1)
    expect(DT[0].last["id"]).to eq(2)
  end
end
