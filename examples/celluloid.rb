# rubocop:disable all
require 'celluloid'
#
# class HelloSpaceActor
#   include Celluloid
#   def say_msg
#     print "Hello, "
#     Celluloid::Actor[:world].say_msg
#   end
# end
#
# class WorldActor
#
#   include Celluloid
#
#   attr_reader :a
#
#   def initialize(a)
#     @a = a
#   end
#
#   def say_msg
#     print "world!"
#     Celluloid::Actor[:newline].say_msg
#   end
# end
#
# class NewlineActor
#   include Celluloid
#   def say_msg
#     print "\n"
#   end
# end
#
# a = Celluloid::Actor[:world] = WorldActor.new('potato')
# puts a.inspect
# r = WorldActor.new('redundant')
# puts r.inspect
# Celluloid::Actor[:newline] = NewlineActor.new
# HelloSpaceActor.new.say_msg
#
#
# class Sheen
#   include Celluloid
#
#   attr_reader :status
#
#   def initialize(name)
#     @name = name
#   end
#
#   def set_status(status)
#     @status = status
#     puts self.status.inspect
#   end
#
#   def report
#     puts "#{@name} is #{@status}"
#   end
# end
#
# charlie = Sheen.new "Charlie Sheen"
# puts charlie.inspect
# charlie.async.set_status "winning!"
# charlie.future.set_status 'it all is fake'
# charlie.report
# charlie.report
# require 'celluloid/autostart'
#
# class Foo
#   include Celluloid
#
#   def execute(x, y, blk)
#     blk.call(x - y)
#   end
#
# end
#
#
# class Bar
#   include Celluloid
#
#   def test_condition(foo)
#     condition = Celluloid::Condition.new
#
#     blk = lambda do |sum|
#       condition.signal(sum)
#     end
#
#     foo.async.execute(190, 87, blk)
#
#     puts "Waiting for foo to complete its execution..."
#     wait_result = condition.wait
#     puts "wait_result [#{wait_result}]"
#     nil
#   end
# end
#
# f = Foo.new
# b = Bar.new
#
# b.test_condition(f)

class TestGroup
  include Celluloid

  attr_reader :s

  def initialize(s)
    @s = s
  end

  def fetch
    checkout do |consumer|
      yield consumer
    end
  end

  private

  def checkout
    consumer = [@s, @s+1, @s+2, @s+3]
    yield consumer
  end

end

class B
  include Celluloid

  attr_reader :groups_array

  def initialize
    @groups_array = [ TestGroup.new(4), TestGroup.new(5), TestGroup.new(6) ]
  end

  def fetch
    groups_array.each do |group|
      group.fetch do |bulk|
       s = Celluloid::Future.new { bulk.each { |m| puts m } }
       s.value
      end
    end
  end
end

B.new.async.fetch

# class DangerMouse
#   include Celluloid
#
#   execute_block_on_receiver :break_the_world
#
#   def break_the_world
#     yield
#   end
# end

# d = DangerMouse.new
# d.break_the_world { A.new('234432342').puts_s }
# d.break_the_world { A.new('1').puts_s }
# d.break_the_world { A.new('2').puts_s }
# d.break_the_world { A.new('3').puts_s }
# d.break_the_world { A.new('4').puts_s }

# rubocop:enable all
