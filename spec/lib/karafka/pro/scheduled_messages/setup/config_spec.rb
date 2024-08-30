# frozen_string_literal: true

RSpec.describe_current do
  it 'expect to use Karafka.producer by default' do
    expect(Karafka::App.config.scheduled_messages.producer).to eq(Karafka.producer)
  end
end
