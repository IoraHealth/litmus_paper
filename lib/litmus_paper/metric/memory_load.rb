module LitmusPaper
  module Metric
    class MemoryLoad
      PARSE_MEMINFO_REGEX = /^([\w\(\)_]+):\s+(\d+)(?:\skB)?$/.freeze

      def initialize(weight, baseline = nil)
        @weight = weight
        @baseline = baseline
      end

      def current_health
        calculated_health = (@weight * mem_capacity).to_i

        if calculated_health > @weight
          @weight
        elsif calculated_health < 1
          1
        else
          calculated_health
        end
      end

      def mem_capacity
        [(mem_available.to_f / baseline), @weight].min
      end

      def mem_available
        stats[:mem_available]
      end

      def mem_total
        stats[:mem_total]
      end

      def baseline
        if @baseline
          mem_total - (mem_total * (@baseline.to_f / 100))
        else
          mem_total
        end
      end

      def stats
        data = meminfo

        {
          mem_total: data['MemTotal'],
          mem_free: data['MemFree'],
          mem_available: data['MemAvailable']
        }
      end

      def to_s
        if @baseline
          "Metric::MemoryLoad(#{@weight}, #{@baseline})"
        else
          "Metric::MemoryLoad(#{@weight})"
        end
      end

      private

      def meminfo
        File.readlines('/proc/meminfo').reduce({}) do |hsh, line|
          if m = line.match(PARSE_MEMINFO_REGEX)
            key, value = m.captures
            hsh[key] = value.to_i
          end

          hsh
        end
      end
    end
  end
end
