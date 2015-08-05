require 'spec_helper'

RSpec.describe Karafka::Concerns::BeforeAction do
  describe '.before_action' do
    let(:dummy_klass) do
      # fake class
      class DummyClass < Karafka::BaseController
        self.group = :testing_api
        self.topic = 'a topic'

        before_action :func

        def process
          puts 'this is process function'
        end

        def func
          params.merge!(a: 4)
          true
        end

        self
      end
    end
    let(:parameters) do
      JSON.generate(
        topic:  :testing_api,
        method: :method_name,
        message: 'result',
        args: %w(arg1 arg2)
      )
    end

    it 'returns method once before action result is true' do
      dummy_klass.before_action { true }
      instance = dummy_klass.new(parameters)
      expect(instance).to receive(:puts)
        .with('this is process function')
      instance.process
    end

    it 'does not return method once before action block result is false' do
      dummy_klass.before_action { false }
      instance = dummy_klass.new(parameters)
      expect(instance).not_to receive(:puts)
        .with('this is process function')
      instance.process
    end

    it 'does not return method once before action method result is false' do
      instance = dummy_klass.new(parameters)
      allow(instance).to receive(:func) { false }
      expect(instance).not_to receive(:puts)
        .with('this is process function')
      instance.process
    end

    it 'has access to params' do
      instance = dummy_klass.new(parameters)
      instance.process
    end
  end
end
