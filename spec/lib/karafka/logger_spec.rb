require 'spec_helper'

RSpec.describe Karafka::Logger do
  specify { expect(described_class).to be < ::Logger }
end
