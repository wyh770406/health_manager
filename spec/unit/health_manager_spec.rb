require 'spec_helper'

describe HealthManager do

  let(:config) do
    {
      'shadow_mode' => 'enable',
      'intervals' => {
        'expected_state_update' => 1.5,
      },
      'logging' => {
        'file' => "/dev/null"
      }
    }
  end

  let(:manager) { HealthManager::Manager.new(config) }

  before do
    EM.error_handler do |e|
      fail "EM error: #{e.message}\n#{e.backtrace}"
    end
  end

  after do
    EM.error_handler # remove our handler
  end

  describe "Manager" do
    it 'should not publish to NATS when registering as vcap_component in shadow mode' do
      in_em do
        NATS.should_receive(:subscribe).once
        NATS.should_not_receive(:publish)
        manager.register_as_vcap_component
      end
    end

    it 'should construct appropriate dependecies' do
      manager.harmonizer.should be_a_kind_of HealthManager::Harmonizer

      manager.reporter.actual_state.should be_a_kind_of HealthManager::AppStateProvider
      manager.harmonizer.varz.should be_a_kind_of HealthManager::Varz
      manager.harmonizer.expected_state_provider.should be_a_kind_of HealthManager::ExpectedStateProvider
      manager.harmonizer.nudger.should be_a_kind_of HealthManager::Nudger
      manager.nudger.publisher.should eq manager.publisher
    end

    it "registers a log counter with the component" do
      log_counter = Steno::Sink::Counter.new
      Steno::Sink::Counter.should_receive(:new).once.and_return(log_counter)

      Steno.should_receive(:init) do |steno_config|
        expect(steno_config.sinks).to include log_counter
      end

      VCAP::Component.should_receive(:register).with(hash_including(:log_counter => log_counter))
      manager.register_as_vcap_component
    end
  end

  describe "Garbage collection of droplets" do
    GRACE_PERIOD = 60

    before do
      app,@expected = make_app
      @hb = make_heartbeat([app])

      @ksp = manager.actual_state
      @ksp.droplets.size.should == 0
      @h = manager.harmonizer

      HealthManager::AppState.droplet_gc_grace_period = GRACE_PERIOD
    end

    it 'should not GC when a recent h/b arrives' do
      @ksp.process_heartbeat(encode_json(@hb))
      @ksp.droplets.size.should == 1
      droplet = @ksp.droplets.values.first

      droplet.should_not be_ripe_for_gc
      @h.gc_droplets

      @ksp.droplets.size.should == 1

      Timecop.travel(Time.now + GRACE_PERIOD + 10)

      droplet.should be_ripe_for_gc

      @h.gc_droplets
      @ksp.droplets.size.should == 0
    end

    it 'should not GC after expected state is set' do
      @ksp.process_heartbeat(encode_json(@hb))
      droplet = @ksp.droplets.values.first

      Timecop.travel(Time.now + GRACE_PERIOD + 10)

      droplet.should be_ripe_for_gc

      droplet.set_expected_state(@expected)
      droplet.should_not be_ripe_for_gc
    end
  end
end
