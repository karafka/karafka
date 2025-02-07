# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      client_id: 'name',
      group_id: 'name',
      shutdown_timeout: 2_000,
      consumer_persistence: true,
      pause_max_timeout: 1_000,
      pause_timeout: 1_000,
      pause_with_exponential_backoff: false,
      max_wait_time: 1_000,
      strict_topics_namespacing: false,
      strict_declarative_topics: false,
      concurrency: 5,
      worker_thread_priority: 0,
      license: {
        token: false,
        entity: ''
      },
      swarm: {
        nodes: 2,
        node: false
      },
      oauth: {
        token_provider_listener: false
      },
      admin: {
        kafka: {},
        group_id: 'karafka_admin',
        max_wait_time: 1_000,
        max_attempts: 10
      },
      internal: {
        supervision_sleep: 0.1,
        forceful_exit_code: 2,
        status: Karafka::Status.new,
        process: Karafka::Process.new,
        tick_interval: 5_000,
        swarm: {
          manager: Karafka::Swarm::Manager.new,
          orphaned_exit_code: 2,
          pidfd_open_syscall: 434,
          pidfd_signal_syscall: 424,
          supervision_interval: 30_000,
          liveness_interval: 10_000,
          liveness_listener: Class.new,
          node_report_timeout: 30_000,
          node_restart_timeout: 5_000
        },
        connection: {
          manager: 1,
          conductor: 1,
          reset_backoff: 1_000,
          listener_thread_priority: 0,
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
            },
            commit: {
              max_attempts: 5,
              wait_time: 1_000
            },
            metadata: {
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
          expansions_selector: Karafka::Processing::ExpansionsSelector.new,
          executor_class: Karafka::Processing::Executor,
          worker_job_call_wrapper: false
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

  context 'when validating supervision_sleep' do
    context 'when supervision_sleep is missing' do
      before { config[:internal].delete(:supervision_sleep) }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when supervision_sleep is not a numeric value' do
      before { config[:internal][:supervision_sleep] = 'not_numeric' }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when supervision_sleep is less than or equal to 0' do
      before { config[:internal][:supervision_sleep] = 0 }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end
  end

  context 'when validating forceful_exit_code' do
    context 'when forceful_exit_code is missing' do
      before { config[:internal].delete(:forceful_exit_code) }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when forceful_exit_code is not an integer' do
      before { config[:internal][:forceful_exit_code] = 'not_integer' }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when forceful_exit_code is less than 0' do
      before { config[:internal][:forceful_exit_code] = -1 }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end
  end

  context 'when validating swarm settings' do
    let(:swarm_config) { config[:swarm] }

    context 'when nodes setting is missing' do
      before { swarm_config.delete(:nodes) }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when nodes is not an integer' do
      before { swarm_config[:nodes] = 'invalid' }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when nodes is less than 1' do
      before { swarm_config[:nodes] = 0 }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when node is missing' do
      before { swarm_config.delete(:node) }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end
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

    context 'when max_wait_time is more than swarm node_report_timeout' do
      before { config[:internal][:swarm][:node_report_timeout] = 1_000 }

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

  context 'when we validate group_id' do
    context 'when group_id is nil' do
      before { config[:group_id] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when group_id is not a string' do
      before { config[:group_id] = 2 }

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

  context 'when we validate worker_thread_priority' do
    context 'when worker_thread_priority is nil' do
      before { config[:worker_thread_priority] = nil }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when worker_thread_priority is not an integer' do
      before { config[:worker_thread_priority] = 2.1 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when worker_thread_priority is less than -3' do
      before { config[:worker_thread_priority] = -4 }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when worker_thread_priority is more than 3' do
      before { config[:worker_thread_priority] = 4 }

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

    context  'when conductor is missing' do
      before { config[:internal][:connection].delete(:conductor) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context  'when manager is missing' do
      before { config[:internal][:connection].delete(:manager) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context  'when reset_backoff is missing' do
      before { config[:internal][:connection].delete(:reset_backoff) }

      it { expect(contract.call(config)).not_to be_success }
    end

    context 'when reset_backoff is too small' do
      before { config[:internal][:connection][:reset_backoff] = 999 }

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

    context 'when we validate listener_thread_priority' do
      context 'when listener_thread_priority is nil' do
        before { config[:internal][:connection][:listener_thread_priority] = nil }

        it { expect(contract.call(config)).not_to be_success }
      end

      context 'when listener_thread_priority is not an integer' do
        before { config[:internal][:connection][:listener_thread_priority] = 2.1 }

        it { expect(contract.call(config)).not_to be_success }
      end

      context 'when listener_thread_priority is less than -3' do
        before { config[:internal][:connection][:listener_thread_priority] = -4 }

        it { expect(contract.call(config)).not_to be_success }
      end

      context 'when listener_thread_priority is more than 3' do
        before { config[:internal][:connection][:listener_thread_priority] = 4 }

        it { expect(contract.call(config)).not_to be_success }
      end
    end

    %i[
      query_watermark_offsets
      offsets_for_times
      committed
      commit
      metadata
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
        # commit does not have a timeout
        next if scope == :commit && field == :timeout

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
      executor_class
      worker_job_call_wrapper
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

  context 'when validating internal swarm settings' do
    let(:internal_swarm_config) do
      config[:internal][:swarm]
    end

    context 'when manager is nil' do
      before { internal_swarm_config[:manager] = nil }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when orphaned_exit_code is not an integer' do
      before { internal_swarm_config[:orphaned_exit_code] = 'invalid' }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when pidfd_open_syscall is below 0' do
      before { internal_swarm_config[:pidfd_open_syscall] = -1 }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when pidfd_signal_syscall is not an integer' do
      before { internal_swarm_config[:pidfd_signal_syscall] = 'invalid' }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when supervision_interval is less than 1000' do
      before { internal_swarm_config[:supervision_interval] = 999 }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when liveness_interval is missing' do
      before { internal_swarm_config.delete(:liveness_interval) }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when liveness_listener is nil' do
      before { internal_swarm_config[:liveness_listener] = nil }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when node_report_timeout is less than 1000' do
      before { internal_swarm_config[:node_report_timeout] = 500 }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end

    context 'when node_restart_timeout is not an integer' do
      before { internal_swarm_config[:node_restart_timeout] = 'invalid' }

      it 'expects to not be successful' do
        expect(contract.call(config)).not_to be_success
      end
    end
  end

  context 'when oauth token_provider_listener does not respond to on_oauthbearer_token_refresh' do
    before { config[:oauth][:token_provider_listener] = true }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when oauth token_provider_listener responds to on_oauthbearer_token_refresh' do
    let(:listener) do
      Class.new do
        def on_oauthbearer_token_refresh(_); end
      end
    end

    before { config[:oauth][:token_provider_listener] = listener.new }

    it { expect(contract.call(config)).to be_success }
  end
end
