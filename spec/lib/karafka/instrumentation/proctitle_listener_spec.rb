# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::ProctitleListener do
  describe '#on_app_initializing' do
    let(:expected_title) { "karafka #{Karafka::App.config.client_id} (initializing)" }

    after { described_class.on_app_initializing({}) }

    it { expect(::Process).to receive(:setproctitle).with(expected_title) }
  end

  describe '#on_app_running' do
    let(:expected_title) { "karafka #{Karafka::App.config.client_id} (running)" }

    after { described_class.on_app_running({}) }

    it { expect(::Process).to receive(:setproctitle).with(expected_title) }
  end

  describe '#on_app_stopping' do
    let(:expected_title) { "karafka #{Karafka::App.config.client_id} (stopping)" }

    after { described_class.on_app_stopping({}) }

    it { expect(::Process).to receive(:setproctitle).with(expected_title) }
  end
end
