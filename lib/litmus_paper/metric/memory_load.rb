module LitmusPaper
  module Metric
    class MemoryLoad
      PARSE_MEMINFO_REGEX = /^([\w\(\)_]+):\s+(\d+)(?:\skB)?$/.freeze

      attr_reader :weight, :baseline, :force_down_at

      def initialize(weight, baseline: nil, force_down_at: nil)
        @weight = weight
        @baseline = baseline
        @force_down_at = force_down_at
      end

      def current_health
        health = mem_capacity
        weighted_health = (@weight * health).floor

        if weighted_health > @weight
          @weight
        elsif force_down_at && health <= force_down_at
          throw(:force_state, :down)
        elsif weighted_health < 1
          0
        else
          weighted_health
        end
      end

      def mem_capacity
        mem_available.to_f / baseline
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
        "Metric::MemoryLoad(#{@weight}, baseline: #{@baseline || 'nil'}, force_down_at: #{@force_down_at || 'nil'})"
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
