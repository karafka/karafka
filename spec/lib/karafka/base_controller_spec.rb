require 'spec_helper'

RSpec.describe Karafka::BaseController do
  let!(:dummmy_class) do
    # fake class
    class DummyClass < Karafka::BaseController
      self
    end
  end
  let!(:another_class) do
    # fake class
    class AnotherClass < Karafka::BaseController
      self
    end
  end
  describe '.descendants' do
    it 'returns descendants' do
      expect(described_class.descendants).to match_array([another_class, dummmy_class])
    end
  end

  describe '.process' do
    it 'fails error' do
      described_class.before_action { true }
      expect { described_class.new(JSON.generate({})).process }
        .to raise_error(NotImplementedError)
    end
  end
end
