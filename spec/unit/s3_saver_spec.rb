require 'spec_helper'
require 'capybara-screenshot/s3_saver'

describe Capybara::Screenshot::S3Saver do
  let(:saver) { double('saver') }
  let(:bucket_name) { double('bucket_name') }
  let(:s3_client) { double('s3_client') }

  let(:s3_saver) { Capybara::Screenshot::S3Saver.new(saver, s3_client, bucket_name) }

  describe '.new_with_configuration' do
    let(:access_key_id) { double('access_key_id') }
    let(:secret_access_key) { double('secret_access_key') }
    let(:s3_client_credentials_using_defaults) {
      {
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      }
    }

    let(:region) { double('region') }
    let(:s3_client_credentials) {
      s3_client_credentials_using_defaults.merge(region: region)
    }

    it 'destructures the configuration into its components' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(Capybara::Screenshot::S3Saver).to receive(:new)

      Capybara::Screenshot::S3Saver.new_with_configuration(saver, {
        s3_client_credentials: s3_client_credentials,
        bucket_name: bucket_name
      })

      expect(Aws::S3::Client).to have_received(:new).with(s3_client_credentials)
      expect(Capybara::Screenshot::S3Saver).to have_received(:new).with(saver, s3_client, bucket_name)
    end

    it 'defaults the region to us-east-1' do
      default_region = 'us-east-1'

      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(Capybara::Screenshot::S3Saver).to receive(:new)

      Capybara::Screenshot::S3Saver.new_with_configuration(saver, {
          s3_client_credentials: s3_client_credentials_using_defaults,
          bucket_name: bucket_name
      })

      expect(Aws::S3::Client).to have_received(:new).with(
        s3_client_credentials.merge(region: default_region)
      )

      expect(Capybara::Screenshot::S3Saver).to have_received(:new).with(saver, s3_client, bucket_name)
    end
  end

  describe '#save' do
    before do
      allow(saver).to receive(:html_saved?).and_return(false)
      allow(saver).to receive(:screenshot_saved?).and_return(false)
      allow(saver).to receive(:save)
    end

    it 'calls save on the underlying saver' do
      expect(saver).to receive(:save)

      s3_saver.save
    end

    it 'uploads the html' do
      html_path = '/foo/bar.html'
      expect(saver).to receive(:html_path).and_return(html_path)
      expect(saver).to receive(:html_saved?).and_return(true)

      html_file = double('html_file')

      expect(File).to receive(:open).with(html_path).and_yield(html_file)

      expect(s3_client).to receive(:put_object).with(
        bucket: bucket_name,
        key: 'bar.html',
        body: html_file
      )

      s3_saver.save
    end

    it 'uploads the screenshot' do
      screenshot_path = '/baz/bim.jpg'
      expect(saver).to receive(:screenshot_path).and_return(screenshot_path)
      expect(saver).to receive(:screenshot_saved?).and_return(true)

      screenshot_file = double('screenshot_file')

      expect(File).to receive(:open).with(screenshot_path).and_yield(screenshot_file)

      expect(s3_client).to receive(:put_object).with(
        bucket: bucket_name,
        key: 'bim.jpg',
        body: screenshot_file
      )

      s3_saver.save
    end
  end

  # Needed because we cannot depend on Verifying Doubles
  # in older RSpec versions
  describe 'an actual saver' do
    it 'implements the methods needed by the s3 saver' do
      instance_methods = Capybara::Screenshot::Saver.instance_methods

      expect(instance_methods).to include(:save)
      expect(instance_methods).to include(:html_saved?)
      expect(instance_methods).to include(:html_path)
      expect(instance_methods).to include(:screenshot_saved?)
      expect(instance_methods).to include(:screenshot_path)
    end
  end

  describe 'any other method' do
    it 'transparently passes through to the saver' do
      allow(saver).to receive(:foo_bar)

      args = double('args')
      s3_saver.foo_bar(*args)

      expect(saver).to have_received(:foo_bar).with(*args)
    end
  end
end