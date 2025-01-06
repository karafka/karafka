# frozen_string_literal: true

require 'karafka/instrumentation/vendors/kubernetes/base_listener'

# This is fully covered in the integration suite
RSpec.describe_current do
  subject(:listener) { described_class.new }

  describe 'events mapping' do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end

  describe '#healthy?' do
    it { expect { listener.healthy? }.to raise_error(NotImplementedError) }
  end
end
