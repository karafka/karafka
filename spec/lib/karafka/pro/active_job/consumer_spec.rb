# frozen_string_literal: true

require 'karafka/pro/active_job/consumer'

RSpec.describe_current do
  it { expect(described_class).to be < Karafka::ActiveJob::Consumer }
end
