# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new }

  before { allow(::Process).to receive(:setproctitle) }

  ::Karafka::Status::STATES.each_key do |state|
    describe "#on_app_#{state}" do
      let(:expected_title) { "karafka #{Karafka::App.config.client_id} (#{state})" }

      before { listener.public_send("on_app_#{state}", {}) }

      it { expect(::Process).to have_received(:setproctitle).with(expected_title) }
    end
  end
end
