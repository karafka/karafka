# frozen_string_literal: true

RSpec.describe_current do
  it { expect(described_class).to be < Karafka::Routing::Features::Base }

  describe '.post_setup' do
    let(:config) { Karafka::App.config }

    context 'when parallel deserialization is disabled' do
      before do
        allow(config.deserializing.parallel).to receive(:active).and_return(false)
      end

      it 'does nothing' do
        expect { described_class.post_setup(config) }.not_to raise_error
      end
    end

    context 'when parallel deserialization is enabled' do
      before do
        allow(config.deserializing.parallel).to receive(:active).and_return(true)
      end

      if RUBY_VERSION < '4.0'
        it 'raises UnsupportedOptionError on Ruby < 4.0' do
          expect { described_class.post_setup(config) }.to raise_error(
            Karafka::Errors::UnsupportedOptionError,
            /Parallel deserializing requires Ruby 4\.0\+/
          )
        end
      else
        it 'starts the Ractor pool' do
          pool = Karafka::Deserializing::Parallel::Pool.instance
          allow(config.deserializing.parallel).to receive(:concurrency).and_return(4)
          allow(pool).to receive(:start)

          described_class.post_setup(config)

          expect(pool).to have_received(:start).with(4)
        end
      end
    end
  end
end
