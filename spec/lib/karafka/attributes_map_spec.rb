# frozen_string_literal: true

RSpec.describe Karafka::AttributesMap do
  subject(:map) { described_class }

  describe '#api_adapter' do
    it 'expect not to duplicate keys across targets' do
      values = map.api_adapter.values.flatten
      expect(values.count).to eq values.uniq.count
    end

    it 'expect to have proper keys for actions' do
      expected_keys = %i[consumer subscribe consumption pause ignored]
      expect(map.api_adapter.keys).to eq(expected_keys)
    end
  end

  describe '#topic' do
    let(:per_topic_specific_attributes) do
      %i[
        name
        consumer
        backend
        parser
        responder
        batch_consuming
      ]
    end

    it 'expect to include only subscribe and per topic specific attributes' do
      attributes = map.topic + per_topic_specific_attributes
      expect(map.api_adapter[:subscribe] - attributes).to be_empty
    end
  end

  describe '#consumer_group' do
    it 'expect not to contain any values from subscribe' do
      map.api_adapter[:subscribe].each do |subscribe_value|
        expect(map.consumer_group).not_to include(subscribe_value)
      end
    end

    it 'expect to include karafka specific settings' do
      expect(map.consumer_group).to include(:batch_fetching)
    end
  end
end
