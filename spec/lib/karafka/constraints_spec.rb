# frozen_string_literal: true

RSpec.describe_current do
  describe '#verify!' do
    context 'when karafka/web is not used' do
      before { allow(described_class).to receive(:require_version).and_return(false) }

      it 'does not raise an error' do
        expect { described_class.verify! }.not_to raise_error
      end
    end

    context 'when karafka/web is used' do
      before { allow(described_class).to receive(:require_version).and_return(true) }

      context 'with version lower than 0.8.0' do
        let(:expected_error) { Karafka::Errors::DependencyConstraintsError }

        before { stub_const('Karafka::Web::VERSION', '0.7.99') }

        it 'raises a DependencyConstraintsError' do
          expect { described_class.verify! }.to raise_error(expected_error)
        end
      end

      context 'with version 0.8.0 or higher' do
        versions = %w[0.8.0 0.9.0 1.0.0]

        versions.each do |version|
          before { stub_const('Karafka::Web::VERSION', version) }

          it "does not raise an error for version #{version}" do
            expect { described_class.verify! }.not_to raise_error
          end
        end
      end
    end
  end
end
