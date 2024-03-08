# frozen_string_literal: true

# We should be able to use testing lib with rspec in a simple manner

setup_karafka
setup_testing(:rspec)

module Visit
  class << self
    def insert_all(data)
      data.each { |datum| DT[0] << datum }
    end

    def count
      DT[0].size
    end
  end
end

class VisitsConsumer < Karafka::BaseConsumer
  def consume
    ::Visit.insert_all messages.payloads
  end
end

draw_routes(VisitsConsumer)

RSpec.describe VisitsConsumer do
  subject(:consumer) { karafka.consumer_for(DT.topic) }

  let(:visitor_id) { SecureRandom.uuid }
  let(:visits) do
    Array.new(2) do
      {
        id: SecureRandom.uuid,
        visited_at: Time.now,
        visitor_id: visitor_id
      }
    end
  end

  before { visits.each { |visit| karafka.produce(visit.to_json) } }

  it 'expects to save the visits' do
    expect { consumer.consume }.to change(Visit, :count).by(2)
  end
end
