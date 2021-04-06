# frozen_string_literal: true

RSpec.describe_current do
  let(:target) { OpenStruct.new }

  describe 'std method proxy' do
    it 'expect to assign based on the name' do
      value = rand
      method_name = :"method#{rand(100)}"
      expect(target).to receive(:"#{method_name}=").with(value)
      described_class.new(target) { public_send(method_name, value) }
    end
  end

  describe 'ignored method proxy' do
    context 'when it is a boolean like named method' do
      it 'expect not to pass it further and raise error' do
        method_name = :"method#{rand(100)}?"
        operation = -> { described_class.new(target) { public_send(method_name, 1) } }
        expect { operation.call }.to raise_error(NoMethodError)
      end
    end

    context 'when it is a bang method' do
      it 'expect not to pass it further and raise error' do
        method_name = :"method#{rand(100)}!"
        operation = -> { described_class.new(target) { public_send(method_name, 1) } }
        expect { operation.call }.to raise_error(NoMethodError)
      end
    end

    context 'when it is an assignment method' do
      it 'expect not to pass it further and raise error' do
        method_name = :"method#{rand(100)}="
        operation = -> { described_class.new(target) { public_send(method_name, 1) } }
        expect { operation.call }.to raise_error(NoMethodError)
      end
    end
  end
end
