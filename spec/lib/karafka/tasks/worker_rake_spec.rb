require 'spec_helper'
require 'rake'

# load 'karafka/tasks/worker.rake'

RSpec.describe 'db:seeds' do
  before { load 'karafka/tasks/worker.rake' }
  let(:args) { double }
  let(:t) { double }
  let(:arg) { "./examples/sidekiq.yml" }
  it '' do
    allow(Kernel).to receive(:system).and_return(true)
    expect{ Rake::Task['karafka:run_worker'] }.to receive(:invoke).and_yield(t, args)
    expect(args).to receive(:[]).with(:yml_link).and_return(arg)


    Rake::Task['karafka:run_worker'].invoke(arg)

    # expect(described_class).to receive(:system).with('')
    # expRake::Task["karafka:run_worker"].invoke
  end
  # "bundle exec sidekiq -r #{Karafka.core_root}/base_worker.rb -C #{args[:yml_link]}"
end