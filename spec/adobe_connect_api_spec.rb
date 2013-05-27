# Copyright (c) 2010 - 2013 SWITCH - Serving Swiss Universities
# Author: Katja Gräfenhain <katja.graefenhain@switch.ch>

require 'spec_helper'
#include '../lib/adobe_connect_api/xml_parser'

# testdata:
MEETING_NAME = 'Testmeeting from RSpec'
URL_PATH = 'rspec_testmeeting'
E_MAIL = 'testuser@switch.ch'
FIRST_NAME = 'Test'
LAST_NAME = 'User'

E_MAIL_2 = 'testuser2@switch.ch'

# API return values
STATUS_OK = 'ok'
NO_DATA = 'no-data'
STATUS_INVALID = 'invalid'
STATUS_NO_ACCESS = 'no-access'
CODE_DUPLICATE = 'duplicate'

describe AdobeConnectAPI do

  before(:each) do
    @interactconfig = YAML::load_file('./config/config.breeze.yml')[ENV["RAILS_ENV"]]
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
      res = @acs.login()
      @acs.get_status_code(res).should match STATUS_OK
    end

    it 'should logout' do
      res = @acs.logout()
      @acs.get_status_code(res).should include(STATUS_OK)
    end

    it 'should not login admin with wrong password' do
      login = @interactconfig['username']
      res = @acs.login(login, 'password')
      @acs.get_status_code(res).should match NO_DATA
    end
  end

  describe 'normal user' do
    before(:each) do
      # login normal user (no admin)
      login = @interactconfig['test_user']
      password = @interactconfig['generic_user_password']
      @acs.login(login, password)

      # delete the meeting if it already exists
      res = @acs.search_meeting(MEETING_NAME)
      sco_id = @acs.get_sco_id_for_unique_name(res, MEETING_NAME)
      @acs.delete_meeting(sco_id) unless sco_id.nil?
    end

    it 'should return the id of my-meetings folder' do
      folder = @acs.get_my_meetings_folder(@interactconfig['test_user'])
      puts folder
      @acs.get_folder_id(folder).to_i.should_not be 0
    end

    it 'should be able to create a meeting' do
      folder = @acs.get_my_meetings_folder(@interactconfig['test_user'])
      folder_id = @acs.get_folder_id(folder)
      res = @acs.create_meeting(MEETING_NAME, folder_id, URL_PATH)

      puts res.inspect

      @acs.get_status_code(res).should include(STATUS_OK)
      @acs.get_sco_id(res).to_i.should_not be 0
    end

    it 'should not be able to create a user' do
      password = @interactconfig['generic_user_password']
      res = @acs.create_user(E_MAIL, E_MAIL, password, FIRST_NAME, LAST_NAME)
      @acs.get_status_code(res).should include(STATUS_NO_ACCESS)
    end
  end


  describe 'admin user' do
    before(:each) do
      # login normal admin user
      login = @interactconfig['username']
      password = @interactconfig['password']
      @acs.login(login, password)

      # delete the users if they already exist
      filter = AdobeConnectApi::FilterDefinition.new
      filter["email"] == E_MAIL
      principal = @acs.get_principal(filter)
      sco_id = @acs.get_principal_id(principal)
      @acs.delete_user(sco_id) unless sco_id.nil?

      filter2 = AdobeConnectApi::FilterDefinition.new
      filter2["email"] == E_MAIL_2
      principal2 = @acs.get_principal(filter2)
      sco_id2 = @acs.get_principal_id(principal2)
      @acs.delete_user(sco_id2) unless sco_id2.nil?
    end

    it 'should be able to create a user' do
      password = @interactconfig['generic_user_password']
      res = @acs.create_user(E_MAIL, E_MAIL, password, FIRST_NAME, LAST_NAME)

      # should contain the status code OK
      @acs.get_status_code(res).should include(STATUS_OK)

      # should return the sco-id of the new user
      @acs.get_principal_id(res).to_i.should_not be 0
    end

    it 'should be able to update the group membership' do
      # get id of the authors group
      filter_authors = AdobeConnectApi::FilterDefinition.new
      filter_authors["type"] == "authors"
      res = @acs.get_principal(filter_authors)
      authors_group_id = @acs.get_principal_id(res)
      authors_group_id.to_i.should_not be 0

      # create user
      password = @interactconfig['generic_user_password']
      res = @acs.create_user(E_MAIL_2, E_MAIL_2, password, FIRST_NAME, LAST_NAME)
      sco_id = @acs.get_principal_id(res)

      @acs.group_membership_update(authors_group_id, sco_id, true).should include(STATUS_OK)
    end

  end


  describe 'creation and deletion of meeting' do
    before(:each) do
      # login normal user
      login = @interactconfig['test_user']
      password = @interactconfig['generic_user_password']
      @acs.login(login, password)

      # get folder id
      @folder_id = @acs.get_folder_id(@acs.get_my_meetings_folder(@interactconfig['test_user']))

      # check if meeting already exists
      res = @acs.search_meeting(MEETING_NAME)
      @sco_id = @acs.get_sco_id_for_unique_name(res, MEETING_NAME)

      if @sco_id.nil?
        # create meeting
        res = @acs.create_meeting(MEETING_NAME, @folder_id, URL_PATH) 
        @sco_id = @acs.get_sco_id(res)
      end
    end

    it 'should not be able to create a meeting with the same url-path again' do
      res = @acs.create_meeting(MEETING_NAME, @folder_id, URL_PATH)

      status = @acs.get_status_code(res)
      status.should include(STATUS_INVALID)

      subcode = @acs.get_invalid_subcode(res)
      subcode.should include(CODE_DUPLICATE)
    end

    it 'should delete the meeting' do
      # delete meeting
      res = @acs.delete_meeting(@sco_id)
      @acs.get_status_code(res).should include(STATUS_OK)

      # try to find meeting again
      res = @acs.search_meeting(MEETING_NAME)
      sco_id = @acs.get_sco_id_for_unique_name(res, MEETING_NAME)
      sco_id.should be_nil
    end

    it 'should be able to add another host' do
      filter = AdobeConnectApi::FilterDefinition.new
      filter["email"] == @interactconfig['username']
      principal = @acs.get_principal(filter)
      principal_id = @acs.get_principal_id(principal)
      res = @acs.permissions_update(principal_id, @sco_id, "host") unless (principal_id.nil? || @sco_id.nil?)
      @acs.get_status_code(res).should include(STATUS_OK)
    end

    it 'should return the sco-info' do 
      res = @acs.sco_info(@sco_id)
      @acs.get_sco_id(res).should eq @sco_id
    end

    it 'should update the meeting attributes' do
      res = @acs.update_meeting(@sco_id, 'description', 'en')
      @acs.get_status_code(res).should match STATUS_OK
    end

  end

end