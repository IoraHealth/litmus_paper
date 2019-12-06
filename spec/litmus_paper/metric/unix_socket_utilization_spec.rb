require 'spec_helper'

describe LitmusPaper::Metric::UnixSocketUtilization do
  describe "mispelled const compatibility is retained" do
    it 'compatibility is retained' do
      LitmusPaper::Metric::UnixSocketUtilitization.should ==
        LitmusPaper::Metric::UnixSocketUtilization
    end
  end

  describe "#current_health" do
    it "returns supplied weight when there is no queued request" do
      LitmusPaper::Metric::UnixSocketUtilization.any_instance.stub(
        :_stats => OpenStruct.new({:queued => 0, :active => 10}),
      )
      health = LitmusPaper::Metric::UnixSocketUtilization.new(
        100,
        '/var/run/foo.sock',
        10
      ).current_health
      health.should == 100
    end

    it "adjusts weight based on queued requests" do
      LitmusPaper::Metric::UnixSocketUtilization.any_instance.stub(
        :_stats => OpenStruct.new({:queued => 7, :active => 10}),
      )
      health = LitmusPaper::Metric::UnixSocketUtilization.new(
        100,
        '/var/run/foo.sock',
        10
      ).current_health
      health.to_i.should == 20
    end

    it "sets weight to 1 when queued requests is more than maxconn" do
      LitmusPaper::Metric::UnixSocketUtilization.any_instance.stub(
        :_stats => OpenStruct.new({:queued => 11, :active => 10}),
      )
      health = LitmusPaper::Metric::UnixSocketUtilization.new(
        100,
        '/var/run/foo.sock',
        10
      ).current_health
      health.should == 1
    end
  end

  describe "#stats" do
    it "reports metrics" do
      LitmusPaper::Metric::UnixSocketUtilization.any_instance.stub(
        :_stats => OpenStruct.new({:queued => 7, :active => 10}),
      )
      metric = LitmusPaper::Metric::UnixSocketUtilization.new(
        100,
        '/var/run/foo.sock',
        10
      )
      metric.stats.should == {
        :socket_active => 10,
        :socket_queued => 7,
        :socket_utilization => 70,
      }
    end
  end
end
