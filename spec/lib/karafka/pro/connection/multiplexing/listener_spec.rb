# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:manager) { Karafka::App.config.internal.connection.manager }
  let(:subscription_group_id) { SecureRandom.uuid }
  let(:event) { { subscription_group_id: subscription_group_id, statistics: statistics } }
  let(:statistics) { { rand => rand } }

  before { allow(manager).to receive(:notice) }

  describe '#on_statistics_emitted' do
    it 'expect to be noticed' do
      listener.on_statistics_emitted(event)

      expect(manager).to have_received(:notice).with(subscription_group_id, statistics)
    end
  end
end
