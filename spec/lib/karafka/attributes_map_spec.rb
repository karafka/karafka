# frozen_string_literal: true

RSpec.describe Karafka::AttributesMap do
  subject(:map) { described_class }

  describe '#config_adapter' do
    it 'expect not to duplicate keys across targets' do
      values = map.config_adapter.values.flatten
      expect(values.count).to eq values.uniq.count
    end

    it 'expect to have proper keys for actions' do
      expected_keys = %i[consumer subscription consuming pausing ignored]
      expect(map.config_adapter.keys).to eq(expected_keys)
    end
  end

  describe '#topic' do
    let(:per_topic_specific_attributes) do
      %i[
        name
        controller
        worker
        backend
        parser
        interchanger
        responder
        batch_processing
      ]
    end

    it 'expect to include only subscription and per topic specific attributes' do
      attributes = map.topic + per_topic_specific_attributes
      expect(map.config_adapter[:subscription] - attributes).to be_empty
    end
  end

  describe '#consumer_group' do
    it 'expect not to contain any values from subscription' do
      map.config_adapter[:subscription].each do |subscription_value|
        expect(map.consumer_group).not_to include(subscription_value)
      end
    end

    it 'expect to include karafka specific settings' do
      expect(map.consumer_group).to include(:batch_consuming)
    end
  end
end
