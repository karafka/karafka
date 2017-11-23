# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ServerCliOptions do
  let(:schema) { described_class }

  let(:config) do
    {
      pid: 'name'
    }
  end

  context 'when config is valid' do
    it { expect(schema.call(config)).to be_success }
  end

  context 'when we want to use consumer groups that are not defined' do
    before { config[:consumer_groups] = [rand.to_s] }

    it { expect(schema.call(config)).not_to be_success }
  end

  context 'when we want to use pidfile that already exists' do
    before { config[:pid] = Tempfile.new.path }

    it { expect(schema.call(config)).not_to be_success }
  end
end
