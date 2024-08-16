# frozen_string_literal: true

RSpec.describe_current do
  subject(:contract) { described_class.new }

  let(:config) do
    {
      recurring_tasks: {
        consumer_class: consumer_class,
        deserializer: Class.new,
        cron_parser_class: Class.new,
        group_id: 'valid_group_id',
        interval: 5_000,
        topics: {
          schedules: 'valid_schedule_topic',
          logs: 'valid_log_topic'
        }
      }
    }
  end

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:recurring_tasks) { config[:recurring_tasks] }

  context 'when config is valid' do
    it { expect(contract.call(config)).to be_success }
  end

  context 'when consumer_class is not a subclass of Karafka::BaseConsumer' do
    before { recurring_tasks[:consumer_class] = Class.new }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when group_id does not match the required format' do
    before { recurring_tasks[:group_id] = 'invalid group id' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when interval is less than 5000 milliseconds' do
    before { recurring_tasks[:interval] = 4_999 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when interval is not an integer' do
    before { recurring_tasks[:interval] = 'not an integer' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when deserializer is nil' do
    before { recurring_tasks[:deserializer] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when cron_parser_class is nil' do
    before { recurring_tasks[:cron_parser_class] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when schedules topic does not match the required format' do
    before { recurring_tasks[:topics][:schedules] = 'invalid schedule topic' }

    it { expect(contract.call(config)).not_to be_success }
  end

  context 'when logs topic does not match the required format' do
    before { recurring_tasks[:topics][:logs] = 'invalid log topic' }

    it { expect(contract.call(config)).not_to be_success }
  end
end
