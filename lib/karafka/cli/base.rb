# frozen_string_literal: true

module Karafka
  class Cli < Thor
    # Base class for all the command that we want to define
    # This base class provides a nicer interface to Thor and allows to easier separate single
    # independent commands
    # In order to define a new command you need to:
    #   - specify its desc
    #   - implement call method
    #
    # @example Create a dummy command
    #   class Dummy < Base
    #     self.desc = 'Dummy command'
    #
    #     def call
    #       puts 'I'm doing nothing!
    #     end
    #   end
    class Base
      include Thor::Shell

      # We can use it to call other cli methods via this object
      attr_reader :cli

      # @param cli [Karafka::Cli] current Karafka Cli instance
      def initialize(cli)
        @cli = cli
      end

      # This method should implement proper cli action
      def call
        raise NotImplementedError, 'Implement this in a subclass'
      end

      class << self
        # Allows to set options for Thor cli
        # @see https://github.com/erikhuda/thor
        # @param option Single option details
        def option(*option)
          @options ||= []
          @options << option
        end

        # Allows to set description of a given cli command
        # @param desc [String] Description of a given cli command
        def desc(desc)
          @desc ||= desc
        end

        # This method will bind a given Cli command into Karafka Cli
        # This method is a wrapper to way Thor defines its commands
        # @param cli_class [Karafka::Cli] Karafka cli_class
        def bind_to(cli_class)
          cli_class.desc name, @desc

          (@options || []).each { |option| cli_class.option(*option) }

          context = self

          cli_class.send :define_method, name do |*args|
            context.new(self).call(*args)
          end
        end

        private

        # @return [String] downcased current class name that we use to define name for
        #   given Cli command
        # @example for Karafka::Cli::Install
        #   name #=> 'install'
        def name
          to_s.split('::').last.downcase
        end
      end
    end
  end
end
