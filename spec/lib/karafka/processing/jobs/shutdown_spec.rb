# frozen_string_literal: true

RSpec.describe_current do
  it 'is an alias for ConsumerGroups::Jobs::Shutdown' do
    expect(described_class).to eq(Karafka::Processing::ConsumerGroups::Jobs::Shutdown)
  end
end
