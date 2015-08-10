require 'spec_helper'

RSpec.describe Karafka::BaseWorker do
  describe '.perform' do
    it 'perform block' do
      expect(STDOUT).to receive(:puts).with('perform')
      described_class.perform { puts 'perform' }
    end
  end
end
