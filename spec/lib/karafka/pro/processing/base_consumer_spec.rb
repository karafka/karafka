# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    instance = working_class.new
    instance.coordinator = coordinator
    instance.singleton_class.include Karafka::Pro::Processing::BaseConsumer
    instance.singleton_class.include Karafka::Processing::Strategies::Default
    instance
  end


  pending
end
