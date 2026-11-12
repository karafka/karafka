# frozen_string_literal: true

RSpec.describe_current do
  let(:target) { OpenStruct.new }

  describe "std method proxy" do
    it "expect to assign based on the name" do
      value = rand
      method_name = :"method#{rand(100)}"
      expect(target).to receive(:"#{method_name}=").with(value)
      described_class.new(target) { public_send(method_name, value) }
    end
  end

  describe "defaults" do
    let(:target) { Struct.new(:max_messages, :max_wait_time).new }
    let(:defaults) do
      lambda do |_|
        max_messages 50
        max_wait_time 500
      end
    end

    it "expect to apply defaults that were not assigned in the block" do
      described_class.new(target, defaults) { max_messages 7 }
      expect(target.max_messages).to eq(7)
      expect(target.max_wait_time).to eq(500)
    end

    it "expect to apply all defaults when there is no block" do
      described_class.new(target, defaults)
      expect(target.max_messages).to eq(50)
      expect(target.max_wait_time).to eq(500)
    end

    it "expect to apply only the block when defaults are nil" do
      described_class.new(target, nil) { max_messages 7 }
      expect(target.max_messages).to eq(7)
      expect(target.max_wait_time).to be_nil
    end
  end

  describe "ignored method proxy" do
    context "when it is a boolean like named method" do
      it "expect not to pass it further and raise error" do
        method_name = :"method#{rand(100)}?"
        operation = -> { described_class.new(target) { public_send(method_name, 1) } }
        expect { operation.call }.to raise_error(NoMethodError)
      end
    end

    context "when it is a bang method" do
      it "expect not to pass it further and raise error" do
        method_name = :"method#{rand(100)}!"
        operation = -> { described_class.new(target) { public_send(method_name, 1) } }
        expect { operation.call }.to raise_error(NoMethodError)
      end
    end

    context "when it is an assignment method" do
      it "expect not to pass it further and raise error" do
        method_name = :"method#{rand(100)}="
        operation = -> { described_class.new(target) { public_send(method_name, 1) } }
        expect { operation.call }.to raise_error(NoMethodError)
      end
    end
  end
end
