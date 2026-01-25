# frozen_string_literal: true

RSpec.describe Karafka::Admin::Configs::Resource do
  subject(:resource) { described_class.new(type: type, name: name) }

  let(:type) { :topic }
  let(:name) { "test_topic" }

  describe "#initialize" do
    context "with valid parameters" do
      it "initializes a resource with the correct type and name" do
        expect(resource.type).to eq(type)
        expect(resource.name).to eq(name)
      end
    end

    context "with an unknown type" do
      let(:type) { :unknown }

      it "raises a KeyError" do
        expect { resource }.to raise_error(KeyError)
      end
    end
  end

  describe "operation methods" do
    let(:config_name) { "test_config" }
    let(:config_value) { "test_value" }

    %i[set delete append subtract].each do |operation_type|
      let(:operations) { resource.instance_variable_get(:@operations) }

      describe "##{operation_type}" do
        subject(:operation) { resource.public_send(operation_type, config_name, config_value) }

        it "adds a config to the #{operation_type} operations list" do
          expect { operation }.not_to raise_error
          expect(operations.values.flatten).not_to be_empty
          expect(operations.values.flatten.first.name).to eq(config_name)
          expect(operations.values.flatten.first.value).to eq(config_value)
        end
      end
    end
  end

  describe "#to_native_hash" do
    subject(:native_hash) { resource.to_native_hash }

    before do
      resource.set("set_config", "set_value")
      resource.delete("delete_config")
      resource.append("append_config", "append_value")
      resource.subtract("subtract_config", "subtract_value")
    end

    it "returns a hash suitable for rdkafka with correct operations and config values" do
      expect(native_hash[:resource_type])
        .to eq(2)
      expect(native_hash[:resource_name])
        .to eq(name)
      expect(native_hash[:configs].length)
        .to eq(4)
      expect(native_hash[:configs])
        .to include(include(name: "set_config", value: "set_value", op_type: 0))
      expect(native_hash[:configs])
        .to include(include(name: "delete_config", value: "", op_type: 1))
      expect(native_hash[:configs])
        .to include(include(name: "append_config", value: "append_value", op_type: 2))
      expect(native_hash[:configs])
        .to include(include(name: "subtract_config", value: "subtract_value", op_type: 3))
    end
  end
end
