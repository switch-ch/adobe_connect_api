require 'spec_helper'

STATUS_OK = 'ok'
NO_DATA = 'no-data'

describe AdobeConnectAPI do

  describe 'GemVersion' do
    # standard test for gem version, see http://nithinbekal.com/2011/writing-ruby-gems-part-5-setting-up-rspec/
    it 'should return correct version string' do
      AdobeConnectAPI.version_string.should == "AdobeConnectAPI version #{AdobeConnectApi::VERSION}"
    end
  end

  describe 'Login & logout' do
    before(:each) do
      @interactconfig = YAML::load_file("./config/config.breeze.yml")[ENV["RAILS_ENV"]]
      url = @interactconfig["url"]

      # open AdobeConnectAPI (use URL from config file)
      @acs = AdobeConnectAPI.new(url, ENV["RAILS_ENV"], nil)
    end

    it 'should login admin' do
      @acs.pointconfig=(@interactconfig)
      # login to Adobe Connect
      res = XmlSimple.xml_in(@acs.login(), { 'KeyAttr' => 'name' })
      status = res['status'].first['code']
      status.should match STATUS_OK
    end

    it 'should logout' do
      res = XmlSimple.xml_in(@acs.logout(), { 'KeyAttr' => 'name' })
      status = res['status'].first['code']
      status.should include(STATUS_OK)
    end

    it 'should not login admin with wrong password' do
      login = @interactconfig["username"]
      res = XmlSimple.xml_in(@acs.login(login, 'password'), { 'KeyAttr' => 'name' })
      status = res['status'].first['code']
      status.should match NO_DATA
    end

  end

end