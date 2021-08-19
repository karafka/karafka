# frozen_string_literal: true

class TestConsumer < Karafka::BaseConsumer
  def consume
    p 'a'
    byebug
  end
end

Karafka::App.consumer_groups.draw do
  consumer_group 'test123' do
    topic 'test' do
      consumer TestConsumer
    end
  end
end

RSpec.describe 'running a Karafka consumer to eat produced messages', type: :integration do
  before do
    Thread.new { Karafka::Server.run }
    p Karafka::App.producer.produce_sync(topic: 'test', payload: 'my message')
    sleep(60)
    Karafka::App.stop!
  end

  it {  }
end
