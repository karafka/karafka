# frozen_string_literal: true

# More scenarios covered by the integrations - here just the basics
RSpec.describe_current do
  subject(:iterator) { described_class.new(topic) }

  let(:topic) { SecureRandom.uuid }

  before { Karafka::Admin.create_topic(topic, 2, 1) }

  it 'expect to start and stop iterator' do
    iterator.each {}
  end
end
