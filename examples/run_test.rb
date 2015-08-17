# rubocop:disable all
require 'poseidon'
require 'poseidon_cluster'
require 'resolv-replace.rb'
require 'karafka'
require 'sidekiq'
require 'sidekiq_glass'

class TestController < Karafka::BaseController
  self.group = :karafka_api14
  self.topic = 'karafka_topic14'

  before_schedule {
    r = rand(50)
    params.merge!(first_round: r)
    r > 25
  }

  before_schedule {
    r = rand(50)
    params.merge!(next_round: r)
    r > 25
  }
  def perform
    file = File.open('params.log', 'a+')
    file.write "#{params}\n"
    file.close
  end
end

class AnotherTestController < Karafka::BaseController
  self.group = :karafka_api13
  self.topic = :karafka_topic13

  def perform
    file = File.open('params2.log', 'a+')
    file.write "#{params}\n"
    file.close
  end

end

# rubocop:enable all