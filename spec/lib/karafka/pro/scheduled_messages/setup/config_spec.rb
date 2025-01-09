# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  it 'expect to use Karafka.producer by default' do
    expect(Karafka::App.config.scheduled_messages.producer).to eq(Karafka.producer)
  end
end
