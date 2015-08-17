# # rubocop:disable all
require 'resolv-replace.rb'
require 'karafka'
require './test'
require 'sidekiq_glass'
class MyWorker < Karafka::BaseWorker

  def after_failure(*usernames)
    # AccountsService.new.reset(usernames)
  end
end
#
# class MyWorker2 < SidekiqGlass::Worker
#   self.timeout = 300
#   sidekiq_options queue: 'highest2'
#
#   def execute(*params)
#     # Marshal.load(klass).send(:perform)
#     file = File.open('params2.log', 'a+')
#     file.write "This is another params: #{params}\n"
#     file.close
#   end
#
#   def after_failure(*usernames)
#     # AccountsService.new.reset(usernames)
#   end
# end
# # rubocop:enable all