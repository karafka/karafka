# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:current_schema_version) { Karafka::Pro::ScheduledMessages::SCHEMA_VERSION }

  let(:expected_error) { Karafka::Pro::ScheduledMessages::Errors::IncompatibleSchemaError }

  describe '.call' do
    context 'when the message schema version is compatible' do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { 'schedule_schema_version' => current_schema_version }
        )
      end

      it 'does not raise an error' do
        expect { described_class.call(message) }.not_to raise_error
      end
    end

    context 'when the message schema version is lower than current version' do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { 'schedule_schema_version' => '0.0.0' }
        )
      end

      it 'does not raise an error' do
        expect { described_class.call(message) }.not_to raise_error
      end
    end

    context 'when the message schema version is higher than current version' do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { 'schedule_schema_version' => '2.0.0' }
        )
      end

      it 'raises an IncompatibleSchemaError' do
        expect { described_class.call(message) }.to raise_error(expected_error)
      end
    end
  end
end
