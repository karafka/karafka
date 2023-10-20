# frozen_string_literal: true

# More scenarios covered by the integrations - here just the basics
RSpec.describe_current do
  subject(:iterator) { described_class.new(topic) }

  let(:topic) { SecureRandom.uuid }

  before { Karafka::Admin.create_topic(topic, 2, 1) }

  it 'expect to start and stop iterator' do
    iterator.each {}
  end

  context 'when there is some data in the topic' do
    before { Karafka.producer.produce_sync(topic: topic, payload: {}.to_json) }

    it 'expect start, stop and get data' do
      existing = nil

      iterator.each do |message|
        existing = message
      end

      expect(existing).not_to be_nil
    end
  end
end
