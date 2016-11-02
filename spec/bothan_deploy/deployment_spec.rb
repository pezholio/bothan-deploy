module BothanDeploy
  describe Deployment do

    before(:each) do
      @platform_api = double("PlatformAPI")
      @app_setup = double("PlatformAPI::AppSetup")
      @pusher_client = double(Pusher::Client)
      @pusher_channel = double(Pusher::Channel)
      allow(PlatformAPI).to receive(:connect_oauth).with('some-token').and_return(@platform_api)
      allow_any_instance_of(described_class).to receive(:pusher_client).and_return(@pusher_client)
      allow(@pusher_client).to receive(:[]).with('app_status').and_return(@pusher_channel)
      allow(@app_setup).to receive(:create).and_return({ 'id' => 'foo-bar' })
      allow(@platform_api).to receive(:app_setup).and_return(@app_setup).at_least(1).times
      allow_any_instance_of(Object).to receive(:sleep)
    end

    it 'builds and reports success' do
      expect(@app_setup).to receive(:info).with('foo-bar').and_return(pending_status, pending_status, complete_status)
      expect(@pusher_channel).to receive(:trigger).with('success', { url: 'http://example.org'})
      deployment = described_class.new.perform('some-token', {some: 'params', and: 'junk'})
    end

    it 'builds and reports an error' do
      expect(@app_setup).to receive(:info).with('foo-bar').and_return(pending_status, pending_status, pending_status, failed_status)
      expect(@pusher_channel).to receive(:trigger).with('failed', { message: 'This didn\'t work' })
      deployment = described_class.new.perform('some-token', {some: 'params', and: 'junk'})
    end

    it 'sets the correct env variables' do
      params = {
        'name' => 'my-awesome-app',
        'username' => 'username',
        'password' => 'password',
        'title' => 'This is a title',
        'description' => 'Here is a description',
        'license' => 'CC-BY-4.0',
        'publisherName' => 'Me',
        'publisherUrl' => 'http://example.com'
      }

      # For some reason Odlifier won't work in test
      allow(Odlifier::License).to receive(:define).with('CC-BY-4.0') {
        Odlifier::License.new({
          title: "Creative Commons Attribution 4.0",
          url: "https://creativecommons.org/licenses/by/4.0/"
        })
      }

      expect(@app_setup).to receive(:create).with({
        app: {
          name: 'my-awesome-app'
        },
        source_blob: {
          url: 'https://github.com/theodi/bothan/tarball/master'
        },
        overrides: {
          env: {
            'METRICS_API_USERNAME'        => 'username',
            'METRICS_API_PASSWORD'        => 'password',
            'METRICS_API_TITLE'           => 'This is a title',
            'METRICS_API_DESCRIPTION'     => 'Here is a description',
            'METRICS_API_LICENSE_NAME'    => 'Creative Commons Attribution 4.0',
            'METRICS_API_LICENSE_URL'     => 'https://creativecommons.org/licenses/by/4.0/',
            'METRICS_API_PUBLISHER_NAME'  => 'Me',
            'METRICS_API_PUBLISHER_URL'   => 'http://example.com',
            'METRICS_API_CERTIFICATE_URL' => '#'
          }
        }
      }).and_return({ 'id' => 'foo-bar' })
      expect(@app_setup).to receive(:info).with('foo-bar').and_return(pending_status, pending_status, complete_status)
      expect(@pusher_channel).to receive(:trigger).with('success', { url: 'http://example.org'})
      deployment = described_class.new.perform('some-token', params)
    end

    private

    def pending_status
      { 'status' => 'pending' }
    end

    def complete_status
      { 'status' => 'succeeded', 'resolved_success_url' => 'http://example.org' }
    end

    def failed_status
      { 'status' => 'failed', 'failure_message' => 'This didn\'t work' }
    end

  end
end
