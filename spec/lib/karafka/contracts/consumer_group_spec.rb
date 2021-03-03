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
        kafka: { 'bootstrap.servers' => 'localhost:9092' },
        max_wait_time: 10_000,
        max_messages: 10,
        manual_offset_management: true
      }
    ]
  end
  let(:config) do
    {
      id: 'id',
      deserializer: Class.new,
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
end
