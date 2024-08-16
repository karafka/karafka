# frozen_string_literal: true

# Code based on https://github.com/siebertm/parse-cron
# License: MIT
# Copyright (C) 2013 Michael Siebert <siebertm85@googlemail.com>

module Karafka
  module Vendor
    # Cron parser that we use to understand the end user cron syntax
    # It is simplified and not as complex as for example fugit, but we use it because we do not
    # have to have a third-party dependency.
    #
    # If you find it insufficient, please replace it with one of your choice with an API adapter
    # wrapper
    class CronParser
      # internal "mutable" time representation
      class InternalTime
        attr_accessor :year, :month, :day, :hour, :min
        attr_accessor :time_source

        def initialize(time,time_source = Time)
          @year = time.year
          @month = time.month
          @day = time.day
          @hour = time.hour
          @min = time.min

          @time_source = time_source
        end

        def to_time
          time_source.utc(@year, @month, @day, @hour, @min, 0)
        end

        def inspect
          [year, month, day, hour, min].inspect
        end
      end

      SYMBOLS = {
         "jan" => "1",
         "feb" => "2",
         "mar" => "3",
         "apr" => "4",
         "may" => "5",
         "jun" => "6",
         "jul" => "7",
         "aug" => "8",
         "sep" => "9",
         "oct" => "10",
         "nov" => "11",
         "dec" => "12",

         "sun" => "0",
         "mon" => "1",
         "tue" => "2",
         "wed" => "3",
         "thu" => "4",
         "fri" => "5",
         "sat" => "6"
      }

      def initialize(source,time_source = Time)
        @source = interpret_vixieisms(source)
        @time_source = time_source
        validate_source
      end

      def next_time(*args)
        self.next(*args)
      end

      def interpret_vixieisms(spec)
        case spec
        when '@reboot'
          raise ArgumentError, "Can't predict last/next run of @reboot"
        when '@yearly', '@annually'
          '0 0 1 1 *'
        when '@monthly'
          '0 0 1 * *'
        when '@weekly'
          '0 0 * * 0'
        when '@daily', '@midnight'
          '0 0 * * *'
        when '@hourly'
          '0 * * * *'
        else
          spec
        end
      end

      # returns the next occurence after the given date
      def next(now = @time_source.now.utc, num = 1)
        t = InternalTime.new(now, @time_source)

        unless time_specs[:month][0].include?(t.month)
          nudge_month(t)
          t.day = 0
        end

        unless interpolate_weekdays(t.year, t.month)[0].include?(t.day)
          nudge_date(t)
          t.hour = -1
        end

        unless time_specs[:hour][0].include?(t.hour)
          nudge_hour(t)
          t.min = -1
        end

        # always nudge the minute
        nudge_minute(t)
        t = t.to_time
        if num > 1
          recursive_calculate(:next,t,num)
        else
          t
        end
      end

      # returns the last occurence before the given date
      def last(now = @time_source.now.utc, num=1)
        t = InternalTime.new(now,@time_source)

        unless time_specs[:month][0].include?(t.month)
          nudge_month(t, :last)
          t.day = 32
        end

        if t.day == 32 || !interpolate_weekdays(t.year, t.month)[0].include?(t.day)
          nudge_date(t, :last)
          t.hour = 24
        end

        unless time_specs[:hour][0].include?(t.hour)
          nudge_hour(t, :last)
          t.min = 60
        end

        # always nudge the minute
        nudge_minute(t, :last)
        t = t.to_time
        if num > 1
          recursive_calculate(:last,t,num)
        else
          t
        end
      end


      SUBELEMENT_REGEX = %r{^(\d+)(-(\d+)(/(\d+))?)?$}

      def parse_element(elem, allowed_range)
        values = elem.split(',').map do |subel|
          if subel =~ /^\*/
            step = subel.length > 1 ? subel[2..-1].to_i : 1
            stepped_range(allowed_range, step)
          else
            if SUBELEMENT_REGEX === subel
              if $5 # with range
                stepped_range($1.to_i..$3.to_i, $5.to_i)
              elsif $3 # range without step
                stepped_range($1.to_i..$3.to_i, 1)
              else # just a numeric
                [$1.to_i]
              end
            else
              raise ArgumentError, "Bad Vixie-style specification #{subel}"
            end
          end
        end.flatten.sort

        [Set.new(values), values, elem]
      end

      protected

      def recursive_calculate(meth,time,num)
        array = [time]
        num.-(1).times do |num|
          array << self.send(meth, array.last)
        end
        array
      end

      # returns a list of days which do both match time_spec[:dom] or time_spec[:dow]
      def interpolate_weekdays(year, month)
        @_interpolate_weekdays_cache ||= {}
        @_interpolate_weekdays_cache["#{year}-#{month}"] ||= interpolate_weekdays_without_cache(year, month)
      end

      def interpolate_weekdays_without_cache(year, month)
        t = Date.new(year, month, 1)
        valid_mday, _, mday_field = time_specs[:dom]
        valid_wday, _, wday_field = time_specs[:dow]

        # Careful, if both DOW and DOM fields are non-wildcard,
        # then we only need to match *one* for cron to run the job:
        if not (mday_field == '*' and wday_field == '*')
          valid_mday = [] if mday_field == '*'
          valid_wday = [] if wday_field == '*'
        end
        # Careful: crontabs may use either 0 or 7 for Sunday:
        valid_wday << 0 if valid_wday.include?(7)

        result = []
        while t.month == month
          result << t.mday if valid_mday.include?(t.mday) || valid_wday.include?(t.wday)
          t = t.succ
        end

        [Set.new(result), result]
      end

      def nudge_year(t, dir = :next)
        t.year = t.year + (dir == :next ? 1 : -1)
      end

      def nudge_month(t, dir = :next)
        spec = time_specs[:month][1]
        next_value = find_best_next(t.month, spec, dir)
        t.month = next_value || (dir == :next ? spec.first : spec.last)

        nudge_year(t, dir) if next_value.nil?

        # we changed the month, so its likely that the date is incorrect now
        valid_days = interpolate_weekdays(t.year, t.month)[1]
        t.day = dir == :next ? valid_days.first : valid_days.last
      end

      def date_valid?(t, dir = :next)
        interpolate_weekdays(t.year, t.month)[0].include?(t.day)
      end

      def nudge_date(t, dir = :next, can_nudge_month = true)
        spec = interpolate_weekdays(t.year, t.month)[1]
        next_value = find_best_next(t.day, spec, dir)
        t.day = next_value || (dir == :next ? spec.first : spec.last)

        nudge_month(t, dir) if next_value.nil? && can_nudge_month
      end

      def nudge_hour(t, dir = :next)
        spec = time_specs[:hour][1]
        next_value = find_best_next(t.hour, spec, dir)
        t.hour = next_value || (dir == :next ? spec.first : spec.last)

        nudge_date(t, dir) if next_value.nil?
      end

      def nudge_minute(t, dir = :next)
        spec = time_specs[:minute][1]
        next_value = find_best_next(t.min, spec, dir)
        t.min = next_value || (dir == :next ? spec.first : spec.last)

        nudge_hour(t, dir) if next_value.nil?
      end

      def time_specs
        @time_specs ||= begin
          # tokens now contains the 5 fields
          tokens = substitute_parse_symbols(@source).split(/\s+/)
          {
            :minute => parse_element(tokens[0], 0..59), #minute
            :hour   => parse_element(tokens[1], 0..23), #hour
            :dom    => parse_element(tokens[2], 1..31), #DOM
            :month  => parse_element(tokens[3], 1..12), #mon
            :dow    => parse_element(tokens[4], 0..6)  #DOW
          }
        end
      end

      def substitute_parse_symbols(str)
        SYMBOLS.inject(str.downcase) do |s, (symbol, replacement)|
          s.gsub(symbol, replacement)
        end
      end


      def stepped_range(rng, step = 1)
        len = rng.last - rng.first

        num = len.div(step)
        result = (0..num).map { |i| rng.first + step * i }

        result.pop if result[-1] == rng.last and rng.exclude_end?
        result
      end


      # returns the smallest element from allowed which is greater than current
      # returns nil if no matching value was found
      def find_best_next(current, allowed, dir)
        if dir == :next
          allowed.sort.find { |val| val > current }
        else
          allowed.sort.reverse.find { |val| val < current }
        end
      end

      def validate_source
        unless @source.respond_to?(:split)
          raise ArgumentError, 'not a valid cronline'
        end
        source_length = @source.split(/\s+/).length
        unless source_length >= 5 && source_length <= 6
          raise ArgumentError, 'not a valid cronline'
        end
      end
    end
  end
end
