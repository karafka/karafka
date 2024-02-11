# frozen_string_literal: true

FactoryBot.define do
  factory :swarm_node, class: 'Karafka::Swarm::Node' do
    transient do
      id { 0 }
      parent_pidfd { Karafka::Swarm::Pidfd.new(::Process.pid) }
    end

    skip_create

    initialize_with do
      new(id, parent_pidfd)
    end
  end

  factory :swarm_node_with_writer, parent: :swarm_node do
    initialize_with do
      reader, writer = IO.pipe

      instance = new(id, parent_pidfd)

      reader.close

      instance.instance_variable_set('@writer', writer)
      instance
    end
  end
end
