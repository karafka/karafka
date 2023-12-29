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
        entity: ''
      },
      admin: {
        kafka: {},
        group_id: 'karafka_admin',
        max_wait_time: 1_000,
        max_attempts: 10
      },
      internal: {
        status: Karafka::Status.new,
        process: Karafka::Process.new,
        tick_interval: 5_000,
        connection: {
          proxy: {
            query_watermark_offsets: {
              timeout: 100,
              max_attempts: 5,
              wait_time: 1_000
            },
            offsets_for_times: {
              timeout: 100,
              max_attempts: 5,
              wait_time: 1_000
            },
            committed: {
              timeout: 100,
              max_attempts: 5,
              wait_time: 1_000
            }
          }
        },
        routing: {
          builder: Karafka::Routing::Builder.new,
          subscription_groups_builder: Karafka::Routing::SubscriptionGroupsBuilder.new
        },
        processing: {
          scheduler_class: Karafka::Processing::Schedulers::Default,
          jobs_builder: Karafka::Processing::JobsBuilder.new,
          jobs_queue_class: Karafka::Processing::JobsQueue,
          coordinator_class: Karafka::Processing::Coordinator,
          partitioner_class: Karafka::Processing::Partitioner,
          strategy_selector: Karafka::Processing::StrategySelector.new,
          expansions_selector: Karafka::Processing::ExpansionsSelector.new
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

  context 'when we check for the errors yml file reference' do
    it 'expect to have all of them defined' do
      stringified = described_class.config.error_messages.to_s

      described_class.rules.each do |rule|
        expect(stringified).to include(rule.path.last.to_s)
      end
    end
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

  context 'when validating admin details' do
    let(:admin_cfg) { config[:admin] }

    context 'when kafka is missing' do
      before { admin_cfg.delete(:kafka) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when kafka scope is empty' do
      before { admin_cfg[:kafka] = {} }

      it { expect(contract.call(config)).to be_success }
    end

    context 'when kafka scope is not a hash' do
      before { admin_cfg[:kafka] = [1, 2, 3] }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when kafka scope has non symbolized keys' do
      before { admin_cfg[:kafka] = { 'test' => 1 } }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when group_id is missing' do
      before { admin_cfg.delete(:group_id) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when group_id is not in an accepted format' do
      before { admin_cfg[:group_id] = '#$%^&*()' }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when group_id is not a string' do
      before { admin_cfg[:group_id] = 100 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when group_id is empty' do
      before { admin_cfg[:group_id] = '' }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is missing' do
      before { admin_cfg.delete(:max_wait_time) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is not bigger than 0' do
      before { admin_cfg[:max_wait_time] = 0 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_wait_time is float' do
      before { admin_cfg[:max_wait_time] = 1.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_attempts is missing' do
      before { admin_cfg.delete(:max_attempts) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_attempts is not bigger than 0' do
      before { admin_cfg[:max_attempts] = 0 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when max_attempts is float' do
      before { admin_cfg[:max_attempts] = 1.1 }

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

    context  'when tick_interval is less than 1 second' do
      before { config[:internal][:tick_interval] = 999 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context  'when tick_interval is missing' do
      before { config[:internal].delete(:tick_interval) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when connection is missing' do
      before { config[:internal].delete(:connection) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when proxy is missing' do
      before { config[:internal][:connection].delete(:proxy) }

      it { expect(contract.call(config)).not_to be_success }
    end

    %i[
      query_watermark_offsets
      offsets_for_times
      committed
    ].each do |scope|
      context "when proxy #{scope} is missing" do
        before { config[:internal][:connection][:proxy].delete(scope) }

        it { expect(contract.call(config)).not_to be_success }
      end

      %i[
        timeout
        max_attempts
        wait_time
      ].each do |field|
        context "when proxy #{scope} #{field} is 0" do
          before { config[:internal][:connection][:proxy][scope][field] = 0 }

          it { expect(contract.call(config)).not_to be_success }
        end

        context "when proxy #{scope} #{field} is not an integer" do
          before { config[:internal][:connection][:proxy][scope][field] = 100.2 }

          it { expect(contract.call(config)).not_to be_success }
        end

        context "when proxy #{scope} #{field} is a string" do
          before { config[:internal][:connection][:proxy][scope][field] = 'test' }

          it { expect(contract.call(config)).not_to be_success }
        end
      end
    end

    context 'when routing builder is missing' do
      before { config[:internal][:routing].delete(:builder) }

      it { expect(contract.call(config)).not_to be_success }
    end

    %i[
      jobs_builder
      jobs_queue_class
      scheduler_class
      coordinator_class
      partitioner_class
      strategy_selector
      expansions_selector
    ].each do |key|
      context "when processing #{key} is missing" do
        before { config[:internal][:processing].delete(key) }

        it { expect(contract.call(config)).not_to be_success }
      end

      context "when processing #{key} is nil" do
        before { config[:internal][:processing][key] = nil }

        it { expect(contract.call(config)).not_to be_success }
      end
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

    context 'when processing scheduler_class is missing' do
      before { config[:internal][:processing].delete(:scheduler_class) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when processing jobs_queue_class is missing' do
      before { config[:internal][:processing].delete(:jobs_queue_class) }

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
