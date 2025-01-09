# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:listener) do
    described_class.new(
      memory_limit: memory_limit,
      consuming_ttl: consuming_ttl,
      polling_ttl: polling_ttl
    )
  end

  let(:memory_limit) { Float::INFINITY }
  let(:consuming_ttl) { 5 * 60 * 1000 }
  let(:polling_ttl) { 5 * 60 * 1000 }
  let(:event) { {} }
  let(:node) { build(:swarm_node) }
  let(:listener_memory_limit) { listener.instance_variable_get(:@memory_limit) }
  let(:listener_consuming_ttl) { listener.instance_variable_get(:@consuming_ttl) }
  let(:listener_polling_ttl) { listener.instance_variable_get(:@polling_ttl) }
  let(:listener_pollings) { listener.instance_variable_get(:@pollings) }
  let(:listener_consumptions) { listener.instance_variable_get(:@consumptions) }

  before do
    allow(listener).to receive(:node).and_return(node)
    allow(node).to receive(:unhealthy)
  end

  describe '#initialize' do
    it 'sets the memory_limit, consuming_ttl, and polling_ttl with provided values' do
      expect(listener_memory_limit).to eq(memory_limit)
      expect(listener_consuming_ttl).to eq(consuming_ttl)
      expect(listener_polling_ttl).to eq(polling_ttl)
    end
  end

  describe '#on_connection_listener_fetch_loop' do
    it 'marks a polling tick' do
      expect { listener.on_connection_listener_fetch_loop(event) }
        .to change(listener_pollings, :size).by(1)
    end
  end

  # Example for consume event, similar approach for revoke, shutting_down, and tick
  describe '#on_consumer_consume' do
    it 'marks a consumption tick' do
      expect { listener.on_consumer_consume(event) }
        .to change(listener_consumptions, :size).by(1)
    end
  end

  describe '#on_error_occurred' do
    it 'clears consumption and polling ticks' do
      # Set up initial state
      listener.on_connection_listener_fetch_loop(event)
      listener.on_consumer_consume(event)

      expect { listener.on_error_occurred(event) }
        .to change(listener_pollings, :empty?).from(false).to(true)
        .and change(listener_consumptions, :empty?).from(false).to(true)
    end
  end

  describe '#on_statistics_emitted' do
    it 'reports healthy or unhealthy status based on conditions' do
      allow(listener).to receive(:rss_mb).and_return(100)
      allow(listener).to receive(:monotonic_now).and_return(0, 1_000, 5_000, 10_000, 15_000)

      listener.on_statistics_emitted(event)
      expect(node).not_to have_received(:unhealthy)
    end
  end
end
