require './app.rb'

task(:environment) {}

Karafka::Loader.new.load(Karafka::App.root)

Dir.glob('lib/tasks/*.rake').each { |r| load r }
