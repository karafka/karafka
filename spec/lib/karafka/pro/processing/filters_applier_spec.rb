# frozen_string_literal: true

RSpec.describe_current do
  subject(:applier) { described_class.new(filters) }

  let(:first_message) { build(:messages_message) }
  let(:last_message) { build(:messages_message) }
  let(:messages) { [first_message, last_message] }

  context 'when filters are empty' do
    let(:filters) { [] }

    it { expect { applier.apply!(messages) }.not_to(change { messages }) }

    it 'expect not to be applied' do
      applier.apply!(messages)
      expect(applier.applied?).to eq(false)
    end

    it 'expect not to have a cursor' do
      applier.apply!(messages)
      expect(applier.cursor).to be_nil
    end

    it 'expect to have skip as an action' do
      applier.apply!(messages)
      expect(applier.action).to eq(:skip)
    end

    it 'expect not to have timeout' do
      applier.apply!(messages)
      expect(applier.timeout).to eq(0)
    end
  end

  context 'when there are no messages' do
    let(:filters) { [Karafka::Pro::Processing::Filters::Throttler.new(10, 10)] }
    let(:messages) { [] }

    it { expect { applier.apply!(messages) }.not_to(change { messages }) }

    it 'expect not to be applied' do
      applier.apply!(messages)
      expect(applier.applied?).to eq(false)
    end

    it 'expect not to have a cursor' do
      applier.apply!(messages)
      expect(applier.cursor).to be_nil
    end

    it 'expect to have skip as an action' do
      applier.apply!(messages)
      expect(applier.action).to eq(:skip)
    end

    it 'expect not to have timeout' do
      applier.apply!(messages)
      expect(applier.timeout).to eq(0)
    end
  end

  context 'when there are messages but no filtering happened' do
    let(:filters) { [Karafka::Pro::Processing::Filters::Throttler.new(10, 10)] }

    it { expect { applier.apply!(messages) }.not_to(change { messages }) }

    it 'expect not to be applied' do
      applier.apply!(messages)
      expect(applier.applied?).to eq(false)
    end

    it 'expect not to have a cursor' do
      applier.apply!(messages)
      expect(applier.cursor).to be_nil
    end

    it 'expect to have skip as an action' do
      applier.apply!(messages)
      expect(applier.action).to eq(:skip)
    end

    it 'expect not to have timeout' do
      applier.apply!(messages)
      expect(applier.timeout).to eq(0)
    end
  end

  context 'when there are messages and filtering happened' do
    let(:filters) { [Karafka::Pro::Processing::Filters::Throttler.new(0, 10)] }

    it { expect { applier.apply!(messages) }.to(change { messages }) }

    it 'expect to be applied' do
      applier.apply!(messages)
      expect(applier.applied?).to eq(true)
    end

    it 'expect to have a cursor' do
      applier.apply!(messages)
      expect(applier.cursor).to eq(first_message)
    end

    it 'expect to have pause as an action' do
      applier.apply!(messages)
      expect(applier.action).to eq(:pause)
    end

    it 'expect to have timeout' do
      applier.apply!(messages)
      expect(applier.timeout).not_to eq(0)
    end
  end

  context 'when there are messages and multiple filters applied' do
    let(:filters) do
      [
        Karafka::Pro::Processing::Filters::Throttler.new(0, 10),
        Karafka::Pro::Processing::Filters::Throttler.new(1, 0)
      ]
    end

    it { expect { applier.apply!(messages) }.to(change { messages }) }

    it 'expect to be applied' do
      applier.apply!(messages)
      expect(applier.applied?).to eq(true)
    end

    it 'expect to have a cursor' do
      applier.apply!(messages)
      expect(applier.cursor).to eq(first_message)
    end

    it 'expect to have pause as an action as the highest importance action' do
      applier.apply!(messages)
      expect(applier.action).to eq(:pause)
    end

    it 'expect to have timeout' do
      applier.apply!(messages)
      expect(applier.timeout).not_to eq(0)
    end
  end

  context 'when there are messages and multiple filters applied but none pauses' do
    let(:filters) do
      [
        Karafka::Pro::Processing::Filters::Throttler.new(1, 10),
        Karafka::Pro::Processing::Filters::Throttler.new(1, 0)
      ]
    end

    before do
      applier.apply!(messages)
      # Backoff so the first throttler goes beyond backoff time
      sleep(0.011)
    end

    it 'expect to be applied' do
      expect(applier.applied?).to eq(true)
    end

    it 'expect to have a cursor' do
      expect(applier.cursor).to eq(last_message)
    end

    it 'expect to have seek as an action as the highest importance action' do
      expect(applier.action).to eq(:seek)
    end

    it 'expect to have timeout' do
      expect(applier.timeout).to eq(0)
    end
  end

  context 'when none of the filters has seek or pause' do
    let(:filters) do
      [
        Karafka::Pro::Processing::Filters::Throttler.new(1, 10),
        Karafka::Pro::Processing::Filters::Throttler.new(1, 0)
      ]
    end

    before do
      filters.each { |filter| allow(filter).to receive(:action).and_return(:skip) }
      applier.apply!(messages)
    end

    it 'expect to be applied' do
      expect(applier.applied?).to eq(true)
    end

    it 'expect to have a cursor' do
      expect(applier.cursor).to eq(last_message)
    end

    it 'expect to have seek as an action as the highest importance action' do
      expect(applier.action).to eq(:skip)
    end
  end
end
