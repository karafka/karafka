# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  before { allow(::Process).to receive(:setproctitle) }

  describe '#on_app_initializing' do
    let(:expected_title) { "karafka #{Karafka::App.config.client_id} (initializing)" }

    before { listener.on_app_initializing({}) }

    it { expect(::Process).to have_received(:setproctitle).with(expected_title) }
  end

  describe '#on_app_running' do
    let(:expected_title) { "karafka #{Karafka::App.config.client_id} (running)" }

    before { listener.on_app_running({}) }

    it { expect(::Process).to have_received(:setproctitle).with(expected_title) }
  end

  describe '#on_app_stopping' do
    let(:expected_title) { "karafka #{Karafka::App.config.client_id} (stopping)" }

    before { listener.on_app_stopping({}) }

    it { expect(::Process).to have_received(:setproctitle).with(expected_title) }
  end
end
