# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:topics) do
    [
      {
        id: 'id',
        name: 'name',
        consumer: Class.new,
        deserializer: Class.new,
        manual_offset_management: false,
        kafka: { 'bootstrap.servers' => 'localhost:9092' }
      }
    ]
  end
  let(:config) do
    {
      id: 'id',
      deserializer: Class.new,
      kafka: { 'bootstrap.servers' => 'localhost:9092' },
      max_messages: 100_000,
      max_wait_time: 10,
      manual_offset_management: false,
      topics: topics
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when we validate topics' do
    context 'when topics is an empty array' do
      before { config[:topics] = [] }

      it { expect(check).not_to be_success }
    end

    context 'when topics is not an array' do
      before { config[:topics] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when topics names are not unique' do
      before { config[:topics][1] = config[:topics][0].dup }

      it { expect(check).not_to be_success }
      it { expect { check.errors }.not_to raise_error }
    end

    context 'when topics names are unique' do
      before do
        config[:topics][1] = config[:topics][0].dup
        config[:topics][1][:name] = rand.to_s
      end

      it { expect(check).to be_success }
    end

    context 'when topics do not comply with the internal contract' do
      before do
        config[:topics][1] = config[:topics][0].dup
        config[:topics][1][:name] = nil
      end

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate id' do
    context 'when id is nil' do
      before { config[:id] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when id is not a string' do
      before { config[:id] = 2 }

      it { expect(check).not_to be_success }
    end

    context 'when id is an invalid string' do
      before { config[:id] = '%^&*(' }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate max_wait_time' do
    context 'when max_wait_time is nil' do
      before { config[:max_wait_time] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when max_wait_time is not integer' do
      before { config[:max_wait_time] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when max_wait_time is less than 0' do
      before { config[:max_wait_time] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate max_messages' do
    context 'when max_messages is nil' do
      before { config[:max_messages] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when max_messages is not integer' do
      before { config[:max_messages] = 's' }

      it { expect(check).not_to be_success }
    end

    context 'when max_messages is less than 1' do
      before { config[:max_messages] = -1 }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate deserializer' do
    context 'when it is not present' do
      before { config[:deserializer] = nil }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate manual_offset_management' do
    context 'when it is not present' do
      before { config.delete(:manual_offset_management) }

      it { expect(check).not_to be_success }
    end

    context 'when it is not boolean' do
      before { config[:manual_offset_management] = nil }

      it { expect(check).not_to be_success }
    end
  end

  context 'when we validate kafka' do
    context 'when it is not present' do
      before { config.delete(:kafka) }

      it { expect(check).not_to be_success }
    end
  end
end
