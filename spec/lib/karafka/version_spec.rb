# frozen_string_literal: true

RSpec.describe Karafka::VERSION do
  it { expect { Karafka::VERSION }.not_to raise_error }
end
