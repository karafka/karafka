# frozen_string_literal: true

RSpec.describe_current do
  subject(:console_cli) { described_class.new }

  specify { expect(described_class).to be < Karafka::Cli::Base }

  let(:info) { Karafka::Cli::Info.new }

  before { allow(info.class).to receive(:new).and_return(info) }

  describe "#call" do
    context "when running without rails" do
      let(:cmd) do
        envs = [
          "KARAFKA_CONSOLE=true",
          "IRBRC='#{Karafka.gem_root}/.console_irbrc'"
        ]
        "#{envs.join(" ")} bundle exec irb -r #{Karafka.boot_file}"
      end

      before do
        allow(Gem).to receive(:bin_path).with("irb", "irb").and_return("/bin/irb")
        allow(info).to receive(:call)
        allow(console_cli).to receive(:exec)
      end

      it "expect to execute irb with boot file required" do
        console_cli.call
        expect(info).to have_received(:call)
        expect(console_cli).to have_received(:exec).with(cmd)
      end

      context "when irb is not in the bundle" do
        before do
          allow(Gem)
            .to receive(:bin_path)
            .with("irb", "irb")
            .and_raise(Gem::Exception, "can't find executable irb for gem irb")
        end

        it "expect to explain how to add irb and exit with an error" do
          expect { console_cli.call }
            .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
            .and output(/Add `gem "irb"` to your Gemfile/).to_stdout

          expect(info).not_to have_received(:call)
          expect(console_cli).not_to have_received(:exec)
        end
      end

      context "when irb gem is not installed" do
        before do
          allow(Gem)
            .to receive(:bin_path)
            .with("irb", "irb")
            .and_raise(Gem::GemNotFoundException, "can't find gem irb")
        end

        it "expect to exit with an error" do
          expect { console_cli.call }
            .to raise_error(SystemExit)
            .and output(/needs the irb gem/).to_stdout

          expect(console_cli).not_to have_received(:exec)
        end
      end
    end

    context "when running with rails" do
      let(:cmd) do
        "KARAFKA_CONSOLE=true bundle exec rails console"
      end

      before do
        allow(Karafka).to receive(:rails?).and_return(true)
        allow(Gem).to receive(:bin_path)
        allow(info).to receive(:call)
        allow(console_cli).to receive(:exec)
      end

      it "expect to execute rails console" do
        console_cli.call
        expect(info).to have_received(:call)
        expect(console_cli).to have_received(:exec).with(cmd)
      end

      it "expect not to check for irb" do
        console_cli.call
        expect(Gem).not_to have_received(:bin_path)
      end
    end
  end

  describe "#names" do
    it { expect(console_cli.class.names).to eq %w[c console] }
  end
end
