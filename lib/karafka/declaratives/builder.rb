# frozen_string_literal: true

module Karafka
  module Declaratives
    # The main entry point for the declaratives subsystem. Returned by `Karafka::App.declaratives`.
    # Provides the `draw` DSL and programmatic access to topic declarations and operations.
    class Builder
      attr_reader :repository

      def initialize
        @repository = Repository.new
        @defaults = nil
      end

      # DSL entry point for declaring topics outside of routing blocks.
      #
      # @param block [Proc] block to evaluate in builder context
      #
      # @example
      #   Karafka::App.declaratives.draw do
      #     topic :orders do
      #       partitions 10
      #       replication_factor 3
      #       config 'retention.ms' => 604_800_000
      #     end
      #   end
      def draw(&block)
        instance_eval(&block)
      end

      # Sets default values applied to every topic declared after this call.
      # Defaults are evaluated before the topic block, so topic-specific values override them.
      #
      # @param block [Proc] block evaluated in each topic's context before the topic block
      def defaults(&block)
        @defaults = block
      end

      # Declares a topic with the given name. If a topic with this name was already declared
      # (via routing bridge or a prior draw call), the existing declaration is returned and
      # the block is evaluated on it (allowing additive configuration).
      #
      # @param name [String, Symbol] topic name
      # @param block [Proc] optional block evaluated in the topic's context
      # @return [Karafka::Declaratives::Topic] the declaration
      def topic(name, &block)
        declaration = @repository.find_or_create(name)
        declaration.instance_eval(&@defaults) if @defaults
        declaration.instance_eval(&block) if block
        declaration
      end

      # @return [Array<Karafka::Declaratives::Topic>] all active topic declarations
      def topics
        @repository.active
      end

      # @param name [String, Symbol] topic name
      # @return [Karafka::Declaratives::Topic, nil] specific topic declaration
      def find_topic(name)
        @repository.find(name)
      end
    end
  end
end
