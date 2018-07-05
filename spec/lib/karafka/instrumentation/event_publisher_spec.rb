# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::EventPublisher do
  describe 'supported events' do
    subject(:events) { described_class.events.keys }

    it { expect(events).to include 'after_init' }
    it { expect(events).to include 'before_fetch_loop' }
  end
end
