# frozen_string_literal: true

RSpec.describe_current do
  describe "#register and #verify!" do
    after do
      # Remove test constraints not to pollute other specs (registrations are global)
      constraints = described_class.send(:constraints)
      constraints[:load].delete(:test_load)
      constraints[:config].delete(:test_config)
    end

    it "rejects unknown phases on registration" do
      expect { described_class.register(:test_load, phase: :boot) {} }
        .to raise_error(Karafka::Errors::UnsupportedCaseError)
    end

    it "rejects unknown phases on verification" do
      expect { described_class.verify!(:boot) }
        .to raise_error(Karafka::Errors::UnsupportedCaseError)
    end

    it "runs only the constraints of the requested phase" do
      ran = []
      described_class.register(:test_load, phase: :load) { ran << :load }
      described_class.register(:test_config, phase: :config) { ran << :config }

      described_class.verify!(:load)

      expect(ran).to eq(%i[load])
    end

    it "passes the config to config-phase constraints" do
      received = nil
      described_class.register(:test_config, phase: :config) { |config| received = config }

      described_class.verify!(:config, :fake_config)

      expect(received).to eq(:fake_config)
    end

    it "overwrites a re-registered constraint instead of accumulating it" do
      runs = 0
      described_class.register(:test_config, phase: :config) { runs += 1 }
      described_class.register(:test_config, phase: :config) { runs += 1 }

      described_class.verify!(:config, nil)

      expect(runs).to eq(1)
    end
  end

  describe "karafka-web load constraint" do
    context "when karafka/web is not used" do
      before { allow(described_class).to receive(:require_version).and_return(false) }

      it "does not raise an error" do
        expect { described_class.verify! }.not_to raise_error
      end
    end

    context "when karafka/web is used" do
      before { allow(described_class).to receive(:require_version).and_return(true) }

      context "with version lower than 0.8.0" do
        let(:expected_error) { Karafka::Errors::DependencyConstraintsError }

        before { stub_const("Karafka::Web::VERSION", "0.7.99") }

        it "raises a DependencyConstraintsError" do
          expect { described_class.verify! }.to raise_error(expected_error)
        end
      end

      context "with version 1.0.0.rc2 or higher" do
        versions = %w[1.0.0.rc2 1.0.0 1.1.0]

        versions.each do |version|
          before { stub_const("Karafka::Web::VERSION", version) }

          it "does not raise an error for version #{version}" do
            expect { described_class.verify! }.not_to raise_error
          end
        end
      end
    end
  end
end
