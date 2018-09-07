# frozen_string_literal: true

RSpec.describe Karafka::Params::Builders::Metadata do
  let(:routing_topic) { build(:routing_topic) }
  let(:kafka_batch) { build(:kafka_fetched_batch) }

  describe '#from_kafka_batch' do
    pending
  end
end
