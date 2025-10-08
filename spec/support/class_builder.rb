# frozen_string_literal: true

# Class builder helps creating anonymous classes that we can use to spec our code
# We need co create new class instances to have an "empty" and "clear" class for each spec
# This module acts as an interface to create classes
module ClassBuilder
  class << self
    # Creates an empty class without any predefined methods
    # @return [Class] created anonymous class
    def build(&)
      klass = Class.new

      klass.class_eval(&) if block_given?
      klass
    end

    # This method allows us to create a class that inherits from any other
    # @param klass [Class] any class from which we want to inherit in our anonymous class
    # @return [Class] new anonymous class
    def inherit(klass, &)
      Class.new(klass, &)
    end
  end
end
