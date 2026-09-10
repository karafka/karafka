# frozen_string_literal: true

# The server CLI options contract should validate share-group include/exclude filters the same
# way it validates consumer-group ones: unknown share group names should be rejected, known ones
# accepted, and share group names must not satisfy the consumer-groups filter validation.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group "existing-cg" do
    topic "t1" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "existing-sg" do
    topic "t2" do
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

activity_manager = Karafka::App.config.internal.routing.activity_manager
contract = Karafka::App.config.internal.cli.contract

# Unknown share group name in the exclusions should be rejected
activity_manager.exclude(:share_groups, "non-existing-sg")

failed = false

begin
  contract.validate!(activity_manager.to_h)
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("share group"), e.message

  failed = true
end

assert failed

activity_manager.clear

# Known share group name in the exclusions should pass
activity_manager.exclude(:share_groups, "existing-sg")
contract.validate!(activity_manager.to_h)

activity_manager.clear

# A share group name must not be accepted by the consumer-groups filter
activity_manager.include(:consumer_groups, "existing-sg")

failed = false

begin
  contract.validate!(activity_manager.to_h)
rescue Karafka::Errors::InvalidConfigurationError => e
  assert e.message.include?("consumer group"), e.message

  failed = true
end

assert failed

activity_manager.clear
