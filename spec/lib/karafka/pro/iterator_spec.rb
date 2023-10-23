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
    before { PRODUCERS.regular.produce_sync(topic: topic, payload: {}.to_json) }

    it 'expect start, stop and get data' do
      existing = nil

      iterator.each do |message|
        existing = message
      end

      expect(existing).not_to be_nil
    end
  end

  context 'when there are only aborted transactions in the topic' do
    before do
      wait_if_needed

      PRODUCERS.transactional.transaction do
        PRODUCERS.transactional.produce_sync(topic: topic, payload: {}.to_json)

        throw(:abort)
      end
    end

    it 'expect start, stop and get no data' do
      existing = nil

      iterator.each do |message|
        existing = message
      end

      expect(existing).to be_nil
    end
  end

  context 'when there are committed transactions in the topic' do
    before do
      wait_if_needed

      PRODUCERS.transactional.transaction do
        PRODUCERS.transactional.produce_sync(topic: topic, payload: {}.to_json)
      end
    end

    it 'expect start, stop and get no data' do
      existing = nil

      iterator.each do |message|
        existing = message
      end

      expect(existing).not_to be_nil
    end
  end

  context 'when we have committed data but way behind failed transactions' do
    subject(:iterator) { described_class.new({ topic => -20 }) }

    before do
      wait_if_needed

      PRODUCERS.transactional.transaction do
        PRODUCERS.transactional.produce_sync(topic: topic, payload: {}.to_json)
      end

      wait_if_needed

      PRODUCERS.transactional.transaction do
        50.times do
          PRODUCERS.transactional.produce_async(topic: topic, payload: {}.to_json)
        end

        throw(:abort)
      end

      wait_if_needed
    end

    it 'expect start, stop and get no data' do
      existing = nil

      iterator.each do |message|
        existing = message
      end

      expect(existing).not_to be_nil
    end
  end
end
