require 'spec_helper'

describe LitmusPaper::Metric::MemoryLoad do
  describe "#current_health" do
    it "is the percent of available memory capacity" do
      LitmusPaper::Metric::MemoryLoad.any_instance.stub(
        mem_total: 4000000,
        mem_available: 1000000,
      )
      mem_load = LitmusPaper::Metric::MemoryLoad.new(40)
      mem_load.current_health.should == 10
    end

    it "is at capacity" do
      LitmusPaper::Metric::MemoryLoad.any_instance.stub(
        mem_total: 4000000,
        mem_available: 0,
      )
      mem_load = LitmusPaper::Metric::MemoryLoad.new(50)
      mem_load.current_health.should == 0
    end

    context 'baseline is set' do
      it 'is the percent of available memory capacity past the baseline' do
        mem_total = 10000000
        mem_available = 1000000
        LitmusPaper::Metric::MemoryLoad.any_instance.stub(
          mem_total: mem_total,
          mem_available: mem_available,
        )
        mem_load = LitmusPaper::Metric::MemoryLoad.new(100, 85)
        mem_load.current_health.should == (
          (mem_available.to_f / (mem_total - (mem_total * 0.85))) * 100
        ).floor
      end

      it 'returns full weight if memory used is below baseline' do
        # 50% of total capacity available vs. 85% used baseline
        LitmusPaper::Metric::MemoryLoad.any_instance.stub(
          mem_total: 10000000,
          mem_available: 5000000,
        )
        mem_load = LitmusPaper::Metric::MemoryLoad.new(20, 85)
        mem_load.current_health.should == 20
      end
    end

    context 'force_down_at is set' do
      it 'throws :force_state with :down when below force_down_at' do
        LitmusPaper::Metric::MemoryLoad.any_instance.stub(
          mem_total: 4000000,
          mem_available: 4096,
        )
        mem_load = LitmusPaper::Metric::MemoryLoad.new(50, nil, 2)
        expect { mem_load.current_health }.to throw_symbol(:force_state, :down)
      end

      it 'throws :force_state with :down when below force_down_at and not weighted according to baseline' do
        LitmusPaper::Metric::MemoryLoad.any_instance.stub(
          mem_total: 4000000,
          mem_available: 80000,
        )
        mem_load = LitmusPaper::Metric::MemoryLoad.new(50, 85, 2)
        expect { mem_load.current_health }.to throw_symbol(:force_state, :down)

        LitmusPaper::Metric::MemoryLoad.any_instance.stub(
          mem_total: 4000000,
          mem_available: 120000,
        )
        mem_load = LitmusPaper::Metric::MemoryLoad.new(50, 85, 2)
        expect { mem_load.current_health }.not_to throw_symbol(:force_state, :down)
      end
    end
  end

  describe "#mem_available" do
    it "is a number" do
      mem_load = LitmusPaper::Metric::MemoryLoad.new(50)
      mem_load.mem_available.should > 0
    end

    it "is not cached" do
      meminfo1 = <<~PROC.split("\n")
        MemTotal:        3686644 kB
        MemFree:         1870228 kB
        MemAvailable:    2890540 kB
      PROC
      meminfo2 = <<~PROC.split("\n")
        MemTotal:        3686644 kB
        MemFree:         1670228 kB
        MemAvailable:    3090540 kB
      PROC

      File.should_receive(:readlines).with('/proc/meminfo').twice.and_return(
        meminfo1,
        meminfo2
      )
      mem_load = LitmusPaper::Metric::MemoryLoad.new(50)
      mem_load.mem_available.should == 2890540
      mem_load.mem_available.should == 3090540
    end
  end

  describe "#stats" do
    it "reports metrics" do
      File.should_receive(:readlines).with('/proc/meminfo').and_return(<<~PROC.split("\n"))
        MemTotal:        3686644 kB
        MemFree:         1870228 kB
        MemAvailable:    2890540 kB
        Buffers:            2068 kB
        Cached:          1217784 kB
        SwapCached:            0 kB
        Active:           720972 kB
        Inactive:         753408 kB
      PROC
      mem_load = LitmusPaper::Metric::MemoryLoad.new(50)
      mem_load.stats.should == {
        mem_total: 3686644,
        mem_free: 1870228,
        mem_available: 2890540
      }
    end
  end

  describe "#to_s" do
    it "is the check name and the maximum weight" do
      mem_load = LitmusPaper::Metric::MemoryLoad.new(50)
      mem_load.to_s.should == "Metric::MemoryLoad(50, nil, nil)"
    end
  end
end
