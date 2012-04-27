require File.join(File.dirname(__FILE__), 'spec_helper')

describe HealthManager do
  #shortcuts
  AppState = HealthManager::AppState
  AppStateProvider = HealthManager::AppStateProvider
  BulkBasedExpectedStateProvider = HealthManager::BulkBasedExpectedStateProvider

  describe AppStateProvider do
    describe '#get_known_state_provider' do
      it 'should return NATS-based provider by default' do
        AppStateProvider.get_known_state_provider.
          should be_an_instance_of(NatsBasedKnownStateProvider)
      end
    end

    describe '#get_expected_state_provider' do
      it 'should return bulk-API-based provider by default' do
        AppStateProvider.get_expected_state_provider.
          should be_an_instance_of(BulkBasedExpectedStateProvider)
      end
    end
  end
end
