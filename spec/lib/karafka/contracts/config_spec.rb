# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      client_id: 'name',
      shutdown_timeout: 10,
      consumer_mapper: Karafka::Routing::ConsumerMapper.new,
      pause_max_timeout: 1_000,
      pause_timeout: 1_000,
      pause_with_exponential_backoff: false,
      concurrency: 5
    }
  end

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when we validate client_id' do
    context 'when client_id is nil' do
      before { config[:client_id] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when client_id is not a string' do
      before { config[:client_id] = 2 }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate shutdown_timeout' do
    context 'when shutdown_timeout is nil' do
      before { config[:shutdown_timeout] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when shutdown_timeout is not an int' do
      before { config[:shutdown_timeout] = 2.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when shutdown_timeout is less then 0' do
      before { config[:shutdown_timeout] = -2 }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate consumer_mapper' do
    context 'when consumer_mapper is nil' do
      before { config[:consumer_mapper] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate pause_max_timeout' do
    context 'when pause_max_timeout is nil' do
      before { config[:pause_max_timeout] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when pause_max_timeout is not an int' do
      before { config[:pause_max_timeout] = 2.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when pause_max_timeout is less then 1' do
      before { config[:pause_max_timeout] = -2 }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate pause_with_exponential_backoff' do
    context 'when pause_with_exponential_backoff is nil' do
      before { config[:pause_with_exponential_backoff] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when pause_with_exponential_backoff is not a bool' do
      before { config[:pause_with_exponential_backoff] = 2.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when pause_timeout is more than pause_max_timeout' do
      before do
        config[:pause_timeout] = 2
        config[:pause_max_timeout] = 1
        config[:pause_with_exponential_backoff] = true
      end

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate concurrency' do
    context 'when concurrency is nil' do
      before { config[:concurrency] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when concurrency is not an int' do
      before { config[:concurrency] = 2.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when concurrency is less then 1' do
      before { config[:concurrency] = 0 }

      it { expect(contract.call(config)).not_to be_success }
    end
  end
end
