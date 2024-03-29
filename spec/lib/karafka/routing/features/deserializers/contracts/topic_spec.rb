# frozen_string_literal: true

RSpec.describe_current do
  subject(:validation) { described_class.new.call(config) }

  let(:config) do
    {
      deserializers: {
        active: true,
        payload: payload_deserializer,
        headers: headers_deserializer,
        key: key_deserializer
      }
    }
  end

  let(:payload_deserializer) { ->(payload) { payload } }
  let(:headers_deserializer) { ->(headers) { headers } }
  let(:key_deserializer) { ->(key) { key } }

  context 'when config is valid' do
    it { expect(validation).to be_success }
  end

  context 'when active is not true' do
    before { config[:deserializers][:active] = false }

    it { expect(validation).not_to be_success }
  end

  context 'when payload deserializer does not respond to call' do
    before { config[:deserializers][:payload] = 'not_a_proc' }

    it { expect(validation).not_to be_success }
  end

  context 'when headers deserializer does not respond to call' do
    before { config[:deserializers][:headers] = 'not_a_proc' }

    it { expect(validation).not_to be_success }
  end

  context 'when key deserializer does not respond to call' do
    before { config[:deserializers][:key] = 'not_a_proc' }

    it { expect(validation).not_to be_success }
  end
end
