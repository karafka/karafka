# frozen_string_literal: true

RSpec.describe_current do
  subject(:server_cli) { described_class.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  describe "#call" do
    before { allow(Karafka::Server).to receive(:run) }

    context "when we run in foreground (not daemonized)" do
      it "expect not to daemonize anything" do
        expect(server_cli).not_to receive(:daemonize)
        server_cli.call
      end
    end
  end

  describe "#print_marketing_info" do
    it { expect { server_cli.send(:print_marketing_info) }.not_to raise_error }

    context "when in pro" do
      before { allow(Karafka).to receive(:pro?).and_return(true) }

      it { expect { server_cli.send(:print_marketing_info) }.not_to raise_error }
    end
  end

  describe "#names" do
    it { expect(server_cli.class.names.sort).to eq %w[s server consumer].sort }
  end
end
