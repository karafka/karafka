# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.new(3) }

  describe "#call" do
    context "when there is no error" do
      it "does not raise" do
        expect { tracker.call(nil, with_messages: false) }.not_to raise_error
      end

      it "resets the count" do
        tracker.call(nil, with_messages: false)
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when there is an error but progress was made" do
      let(:error) { Rdkafka::RdkafkaError.new(-1) }

      it "does not raise" do
        expect { tracker.call(error, with_messages: true) }.not_to raise_error
      end

      it "resets the count" do
        tracker.instance_variable_set(:@count, 2)
        tracker.call(error, with_messages: true)
        expect(tracker.instance_variable_get(:@count)).to eq(0)
      end
    end

    context "when there is an error and no progress" do
      let(:error) { Rdkafka::RdkafkaError.new(-1) }

      it "does not raise before the threshold" do
        expect { tracker.call(error, with_messages: false) }.not_to raise_error
        expect { tracker.call(error, with_messages: false) }.not_to raise_error
      end

      it "raises at the threshold" do
        tracker.instance_variable_set(:@count, 2)
        expect { tracker.call(error, with_messages: false) }.to raise_error(Rdkafka::RdkafkaError)
      end

      it "raises the error that was passed in" do
        tracker.instance_variable_set(:@count, 2)
        expect { tracker.call(error, with_messages: false) }.to raise_error(error)
      end
    end
  end

  describe "#reset" do
    it "clears the count" do
      tracker.instance_variable_set(:@count, 5)
      tracker.reset
      expect(tracker.instance_variable_get(:@count)).to eq(0)
    end
  end
end
