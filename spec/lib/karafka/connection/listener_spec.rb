# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new(subscription_group, jobs_queue) }

  let(:subscription_group) { nil }
  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }

  pending
end
