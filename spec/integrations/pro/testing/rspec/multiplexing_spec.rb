# frozen_string_literal: true

# We should be able to use testing with multiplexing without any exceptions

setup_karafka
setup_testing(:rspec)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes do
  subscription_group :test do
    multiplexing(max: 2)

    topic DT.topic do
      consumer Consumer
    end
  end
end

RSpec.describe Consumer do
  subject(:consumer) { karafka.consumer_for(DT.topic) }

  before { karafka.produce('test') }

  it 'expects to increase count' do
    expect { consumer.consume }.to change(DT[0], :count).by(1)
  end
end
