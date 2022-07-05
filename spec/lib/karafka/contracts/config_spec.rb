# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      client_id: 'name',
      shutdown_timeout: 10,
      consumer_mapper: Karafka::Routing::ConsumerMapper.new,
      consumer_persistence: true,
      pause_max_timeout: 1_000,
      pause_timeout: 1_000,
      pause_with_exponential_backoff: false,
      max_wait_time: 5,
      concurrency: 5,
      license: {
        token: false,
        entity: '',
        expires_on: Date.parse('2100-01-01')
      },
      internal: {
        status: Karafka::Status.new,
        process: Karafka::Process.new,
        routing: {
          builder: Karafka::Routing::Builder.new,
          subscription_groups_builder: Karafka::Routing::SubscriptionGroupsBuilder.new
        },
        processing: {
          scheduler: Karafka::Processing::Scheduler.new,
          jobs_builder: Karafka::Processing::JobsBuilder.new,
          coordinator_class: Karafka::Processing::Coordinator,
          partitioner_class: Karafka::Processing::Partitioner
        },
        active_job: {
          dispatcher: Karafka::ActiveJob::Dispatcher.new,
          job_options_contract: Karafka::ActiveJob::JobOptionsContract.new,
          consumer_class: Karafka::ActiveJob::Consumer
        }
      },
      kafka: {
        'bootstrap.servers': '127.0.0.1:9092'
      }
    }
  end

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when validating kafka details' do
    context 'when kafka is missing' do
      before { config.delete(:kafka) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when kafka scope is empty' do
      before { config[:kafka] = {} }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when kafka scope is not a hash' do
      before { config[:kafka] = [1, 2, 3] }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when kafka scope has non symbolized keys' do
      before { config[:kafka] = { 'test' => 1 } }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when validating license related components' do
    context 'when license is missing completely' do
      before { config.delete(:license) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when token is nil' do
      before { config[:license][:token] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when entity token is nil' do
      before { config[:license][:entity] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when expires_on is nil' do
      before { config[:license][:expires_on] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end
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

  context 'when we validate max_wait_time' do
    context 'when max_wait_time is nil' do
      before { config[:max_wait_time] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is not an int' do
      before { config[:max_wait_time] = 2.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is less then 0' do
      before { config[:max_wait_time] = -2 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is equal to shutdown_timeout' do
      before do
        config[:max_wait_time] = 5
        config[:shutdown_timeout] = 5
      end

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is more than shutdown_timeout' do
      before do
        config[:max_wait_time] = 15
        config[:shutdown_timeout] = 5
      end

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate consumer_mapper' do
    context 'when consumer_mapper is nil' do
      before { config[:consumer_mapper] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate consumer_persistence' do
    context 'when consumer_persistence is nil' do
      before { config[:consumer_persistence] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when consumer_persistence is not a bool' do
      before { config[:consumer_persistence] = 2.1 }

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

  context 'when we validate internal components' do
    context 'when internals are missing' do
      before { config.delete(:internal) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when routing builder is missing' do
      before { config[:internal][:routing].delete(:builder) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when processing jobs_builder is missing' do
      before { config[:internal][:processing].delete(:jobs_builder) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when status is missing' do
      before { config[:internal].delete(:status) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when process is missing' do
      before { config[:internal].delete(:process) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when routing subscription_groups_builder is missing' do
      before { config[:internal][:routing].delete(:subscription_groups_builder) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when processing scheduler is missing' do
      before { config[:internal][:processing].delete(:scheduler) }

      it { expect(contract.call(config)).not_to be_success }
    end
  end

  context 'when we validate internal active job components' do
    context 'when active_job settings are missing' do
      before { config[:internal].delete(:active_job) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when active_job dispatcher is missing' do
      before { config[:internal][:active_job].delete(:dispatcher) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when active_job job_options_contract is missing' do
      before { config[:internal][:active_job].delete(:job_options_contract) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when active_job consmer class is missing' do
      before { config[:internal][:active_job].delete(:consumer_class) }

      it { expect(contract.call(config)).not_to be_success }
    end
  end
end
