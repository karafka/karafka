# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# More scenarios covered by the integrations - here just the basics
RSpec.describe_current do
  subject(:iterator) { described_class.new(topic) }

  let(:topic) { "it-#{SecureRandom.uuid}" }

  before { Karafka::Admin.create_topic(topic, 2, 1) }

  it 'expect to start and stop iterator' do
    iterator.each { nil }
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

        raise(WaterDrop::AbortTransaction)
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
          PRODUCERS.transactional.produce_sync(topic: topic, payload: {}.to_json)
        end

        wait_if_needed

        raise(WaterDrop::AbortTransaction)
      end

      wait_if_needed
    end

    it 'expect start, stop and get no data' do
      existing = nil

      iterator.each do |message|
        existing = message
      end

      # This spec is a bit tricky. Under heavy load on CI, the aborted transaction may not create
      # records fast enough for the watermark offset to be updated. This means, that we will get
      # the first offset of the successful message instead of last 20 empty from aborted.
      # In both cases we check that we do not get aborted data, so it is ok to check it that way.
      offset = existing&.offset || 0

      expect(offset).to eq(0)
    end
  end
end
