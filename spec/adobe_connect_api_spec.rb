require 'spec_helper'

# testdata:
MEETING_NAME = 'Testmeeting from RSpec'
URL_PATH = 'rspec_testmeeting'
E_MAIL = 'testuser@switch.ch'
FIRST_NAME = 'Test'
LAST_NAME = 'User'

# API return values
STATUS_OK = 'ok'
NO_DATA = 'no-data'
STATUS_INVALID = 'invalid'
STATUS_NO_ACCESS = 'no-access'
CODE_DUPLICATE = 'duplicate'

describe AdobeConnectAPI do

  before(:each) do
    @interactconfig = YAML::load_file("./config/config.breeze.yml")[ENV["RAILS_ENV"]]
    url = @interactconfig['url']

    # open AdobeConnectAPI (use URL from config file)
    @acs = AdobeConnectAPI.new(url, ENV['RAILS_ENV'], nil)
  end

  describe 'GemVersion' do
    # standard test for gem version, see http://nithinbekal.com/2011/writing-ruby-gems-part-5-setting-up-rspec/
    it 'should return correct version string' do
      AdobeConnectAPI.version_string.should == "AdobeConnectAPI version #{AdobeConnectApi::VERSION}"
    end
  end

  describe 'Login & logout' do
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
      login = @interactconfig['username']
      res = XmlSimple.xml_in(@acs.login(login, 'password'), { 'KeyAttr' => 'name' })
      status = res['status'].first['code']
      status.should match NO_DATA
    end
  end

  describe 'normal user' do
    before(:each) do
      # login normal user (no admin)
      login = @interactconfig['test_user']
      password = @interactconfig['generic_user_password']
      @acs.login(login, password)

      # delete the meeting if it already exists
      sco_id = @acs.search_unique_name(MEETING_NAME)
      @acs.delete_meeting(sco_id) unless sco_id.nil?
    end

    it 'should return the id of my-meetings folder' do
      res = @acs.get_my_meetings_folder_id(@interactconfig['test_user'])
      res.to_i.should_not be 0
    end

    it 'should be able to create a meeting' do
      folder_id = @acs.get_my_meetings_folder_id(@interactconfig['test_user'])
      res = @acs.create_meeting(MEETING_NAME, folder_id, URL_PATH)
      # should return the sco-id of the created meeting
      res.to_i.should_not be 0
    end

    it 'should not be able to create a user' do
      password = @interactconfig['generic_user_password']
      res = @acs.create_user(E_MAIL, E_MAIL, password, FIRST_NAME, LAST_NAME)
      status = res['status'].first['code']
      status.should include(STATUS_NO_ACCESS)
    end
  end


  describe 'admin user' do
    before(:each) do
      # login normal user (no admin)
      login = @interactconfig['username']
      password = @interactconfig['password']
      @acs.login(login, password)

      # delete the user if it already exists
      filter = AdobeConnectApi::FilterDefinition.new
      filter["email"] == E_MAIL
      sco_id = @acs.get_principal_id(filter)
      @acs.delete_user(sco_id) unless sco_id.nil?
    end

    it 'should be able to create a user' do
      password = @interactconfig['generic_user_password']
      res = @acs.create_user(E_MAIL, E_MAIL, password, FIRST_NAME, LAST_NAME)
      # should return the sco-id of the new user
      res.to_i.should_not be 0
    end
  end


  describe 'creation and deletion of meeting' do
    before(:each) do
      # login normal user
      login = @interactconfig['test_user']
      password = @interactconfig['generic_user_password']
      @acs.login(login, password)

      # create meeting
      folder_id = @acs.get_my_meetings_folder_id(@interactconfig['test_user'])
      res = @acs.create_meeting(MEETING_NAME, folder_id, URL_PATH)
    end

    it 'should not be able to create a meeting with the same url-path again' do
      folder_id = @acs.get_my_meetings_folder_id(@interactconfig['test_user'])
      res2 = @acs.create_meeting(MEETING_NAME, folder_id, URL_PATH)
      status = res2['status'].first['code']
      status.should include(STATUS_INVALID)
      code = res2['status'].first['invalid'].first['subcode']
      code.should include(CODE_DUPLICATE)
    end

    it 'should find and delete the meeting' do
      # find meeting
      sco_id = @acs.search_unique_name(MEETING_NAME)
      sco_id.should_not be_nil
      # delete meeting
      res = XmlSimple.xml_in(@acs.delete_meeting(sco_id))
      status = res['status'].first['code']
      status.should include(STATUS_OK)
      # try to find meeting again
      sco_id = @acs.search_unique_name(MEETING_NAME)
      sco_id.should be_nil
    end
  end

end