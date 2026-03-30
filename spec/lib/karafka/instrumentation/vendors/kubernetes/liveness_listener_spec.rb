# frozen_string_literal: true

require "karafka/instrumentation/vendors/kubernetes/liveness_listener"

# This is fully covered in the integration suite
RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { {} }
  let(:pollings) { listener.instance_variable_get(:@pollings) }
  let(:consumptions) { listener.instance_variable_get(:@consumptions) }

  describe "events mapping" do
    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end

  describe "fiber-safety" do
    it "tracks polling timestamps independently per fiber" do
      fiber1_id = nil
      fiber2_id = nil

      f1 = Fiber.new do
        fiber1_id = Fiber.current.object_id
        listener.on_connection_listener_fetch_loop(event)
      end

      f2 = Fiber.new do
        fiber2_id = Fiber.current.object_id
        listener.on_connection_listener_fetch_loop(event)
      end

      f1.resume
      f2.resume

      expect(pollings.keys).to contain_exactly(fiber1_id, fiber2_id)
    end

    it "tracks consumption timestamps independently per fiber" do
      fiber1_id = nil
      fiber2_id = nil

      f1 = Fiber.new do
        fiber1_id = Fiber.current.object_id
        listener.on_consumer_consume(event)
      end

      f2 = Fiber.new do
        fiber2_id = Fiber.current.object_id
        listener.on_consumer_consume(event)
      end

      f1.resume
      f2.resume

      expect(consumptions.keys).to contain_exactly(fiber1_id, fiber2_id)
    end

    it "clearing in one fiber does not remove the other fibers timestamp" do
      f1 = Fiber.new do
        listener.on_consumer_consume(event)
        Fiber.yield
        listener.on_consumer_consumed(event)
      end

      f2 = Fiber.new do
        listener.on_consumer_consume(event)
      end

      # Both fibers mark consumption
      f1.resume
      f2.resume
      expect(consumptions.size).to eq(2)

      # Only f1 clears its entry
      f1.resume
      expect(consumptions.size).to eq(1)
    end
  end
end
