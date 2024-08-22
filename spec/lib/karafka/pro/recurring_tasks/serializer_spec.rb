# frozen_string_literal: true

RSpec.describe_current do
  subject(:serializer) { described_class.new }

  let(:task) do
    Karafka::Pro::RecurringTasks::Task.new(
      id: 'task_1',
      cron: '* * * * *',
      previous_time: Time.now - 3600
    )
  end

  let(:schedule) do
    schedule = Karafka::Pro::RecurringTasks::Schedule.new(version: '1.0.0')
    schedule << task
    schedule
  end

  let(:event) do
    Karafka::Core::Monitoring::Event.new(
      :event,
      {
        task: task,
        time: 100
      }
    )
  end

  describe '#schedule' do
    it 'serializes and compresses the schedule' do
      compressed_data = serializer.schedule(schedule)
      decompressed_data = Zlib::Inflate.inflate(compressed_data)
      parsed_data = JSON.parse(decompressed_data)

      expect(parsed_data['schema_version']).to eq('1.0')
      expect(parsed_data['schedule_version']).to eq(schedule.version)
      expect(parsed_data['type']).to eq('schedule')
      expect(parsed_data['tasks'][task.id]).to include(
        'id' => task.id,
        'cron' => task.cron.original,
        'previous_time' => task.previous_time.to_i,
        'next_time' => task.next_time.to_i,
        'enabled' => task.enabled?
      )
    end
  end

  describe '#command' do
    let(:command_name) { 'pause' }
    let(:task_id) { 'task_1' }
    let(:schedule) { Karafka::Pro::RecurringTasks::Schedule.new(version: '1.0.0') }

    before { allow(::Karafka::Pro::RecurringTasks).to receive(:schedule).and_return(schedule) }

    it 'serializes and compresses the command data' do
      compressed_data = serializer.command(command_name, task_id)
      decompressed_data = Zlib::Inflate.inflate(compressed_data)
      parsed_data = JSON.parse(decompressed_data)

      expect(parsed_data['schema_version']).to eq('1.0')
      expect(parsed_data['schedule_version']).to eq(schedule.version)
      expect(parsed_data['type']).to eq('command')
      expect(parsed_data['command']).to include('name' => command_name)
      expect(parsed_data['task']).to include('id' => task_id)
    end
  end

  describe '#log' do
    let(:schedule) { Karafka::Pro::RecurringTasks::Schedule.new(version: '1.0.0') }

    before { allow(::Karafka::Pro::RecurringTasks).to receive(:schedule).and_return(schedule) }

    it 'serializes and compresses the log event data' do
      compressed_data = serializer.log(event)
      decompressed_data = Zlib::Inflate.inflate(compressed_data)
      parsed_data = JSON.parse(decompressed_data)

      expect(parsed_data['schema_version']).to eq('1.0')
      expect(parsed_data['schedule_version']).to eq(schedule.version)
      expect(parsed_data['type']).to eq('log')
      expect(parsed_data['task']).to include(
        'id' => task.id,
        'time_taken' => event[:time],
        'result' => 'success'
      )
    end

    context 'when the event contains an error' do
      let(:event) do
        Karafka::Core::Monitoring::Event.new(
          :event,
          {
            task: task,
            time: 120,
            error: StandardError.new
          }
        )
      end

      it 'serializes and compresses the log event data with failure result' do
        compressed_data = serializer.log(event)
        decompressed_data = Zlib::Inflate.inflate(compressed_data)
        parsed_data = JSON.parse(decompressed_data)

        expect(parsed_data['schema_version']).to eq('1.0')
        expect(parsed_data['schedule_version']).to eq(schedule.version)
        expect(parsed_data['type']).to eq('log')
        expect(parsed_data['task']).to include(
          'id' => task.id,
          'time_taken' => event.payload[:time],
          'result' => 'failure'
        )
      end
    end

    context 'when the event does not contain a time' do
      let(:event) do
        Karafka::Core::Monitoring::Event.new(
          :event,
          {
            task: task,
            error: StandardError.new
          }
        )
      end

      it 'sets time_taken to -1 in the serialized data' do
        compressed_data = serializer.log(event)
        decompressed_data = Zlib::Inflate.inflate(compressed_data)
        parsed_data = JSON.parse(decompressed_data)

        expect(parsed_data['task']['time_taken']).to eq(-1)
      end
    end
  end

  describe '#serialize' do
    let(:hash) { { key: 'value' } }

    it 'serializes a hash to JSON' do
      expect(serializer.send(:serialize, hash)).to eq(hash.to_json)
    end
  end

  describe '#compress' do
    let(:data) { 'test_data' }

    it 'compresses the data using Zlib' do
      compressed_data = serializer.send(:compress, data)
      expect(Zlib::Inflate.inflate(compressed_data)).to eq(data)
    end
  end
end
