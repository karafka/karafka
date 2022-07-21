# frozen_string_literal: true

require 'karafka/pro/contracts/base'

RSpec.describe_current do
  it { expect(described_class).to be < ::Karafka::Contracts::Base }
end
