# encoding: utf-8

# Copyright (c) 2010 - 2013 SWITCH - Serving Swiss Universities
# Author: Mischael Schill <me@mschill.ch>
#         Martin Kos <martin@kos.li>
#         Christian Rohrer <christian.rohrer@switch.ch>
#         Katja Gräfenhain <katja.graefenhain@switch.ch>
# $Id$

require 'rubygems'
# require "net/http"
require "net/https"
require "uri"
require 'xmlsimple'
require "cgi"
require "yaml"
#require 'logger'

require 'adobe_connect_api/version'
require 'adobe_connect_api/filter_definition'
require 'adobe_connect_api/sort_definition'
require 'adobe_connect_api/result'
require 'adobe_connect_api/xml_parser'


# This class is a simple utility to acces the adobe connect api. Before
# making any queries use the login-method
# There are dedicated methods for some of the actions of the api and a generic
# "query"-method for all the others.
# All the actions are defined in the Adobe Connect Pro API documentation
# some of the actions are accepting filter- and/or sorting-definitions.

# NOTE KG: refactored so that all methods return the body of the query result, e.g.
# "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<results><status code=\"ok\"/><sco account-id=\"7\" disabled=\"\" display-seq=\"0\" folder-id=\"14152063\" 
# icon=\"meeting\" lang=\"en\" max-retries=\"\" sco-id=\"14153596\" source-sco-id=\"\" type=\"meeting\" version=\"0\"><date-created>2013-03-27T17:55:36.403+01:00</date-created><
# date-modified>2013-03-27T17:55:36.403+01:00</date-modified><name>Testmeeting from RSpec</name><url-path>/rspec_testmeeting/</url-path></sco></results>"

class AdobeConnectAPI
  include XMLParser

  attr :url
  attr :pointconfig

  def self.version_string
    "AdobeConnectAPI version #{AdobeConnectApi::VERSION}"
  end

  # return BREEZESESSION id
  def sessionid
    @sessionid
  end

  def pointconfig=(pointconfig)
    if pointconfig == nil
      pointconfig = YAML::load_file("#{root_directory}/config/config.breeze.yml")[environment]
    else
      @pointconfig = pointconfig
    end
  end

  #The URL is the base URL of the Connect-Server, without the trailing slash
  def initialize (url = nil, environment, root_directory)
    begin
      @pointconfig = YAML::load_file("#{root_directory}/config/config.breeze.yml")[environment]
    rescue
       # should not occur except when running tests
    end
    if (url == nil)
      @url = @pointconfig["url"]
    else
      @url = url
    end
  end

  #makes the login to the server
  def login (login = nil, password = nil, account_id=nil, external_auth=nil, domain=nil)

    if (login != nil && password == nil)
      # user given --> use generic user password
      # TODO: generate password (see https://forge.switch.ch/redmine/issues/2355)
      password = @pointconfig["generic_user_password"]
    elsif (login == nil) && (password == nil)
       login = @pointconfig["username"]
       password = @pointconfig["password"]
    end

    res = query("login",
      "login" => login,
      "password" => password,
      "account-id" => account_id,
      "external-auth" => external_auth,
      "domain" => domain)

    cookies = res.response["set-cookie"]
    puts cookies.inspect
    cookies.split(";").each{|s|
      array = s.split("=")
      if array[0] == "BREEZESESSION"
        @sessionid = array[1]
      end
    }
    puts "ACS: Logged in"
    return res.body
  end

  #makes a logout and removes the cookie
  def logout
    res = query("logout")
    @sessionid = nil
    puts "ACS: Logged out"
    return res.body
  end

  # creates a new user in Adobe Connect
  def create_user(email = nil, login = nil, password = nil, first_name = nil, last_name = nil)
    if password == nil
      password = @pointconfig["generic_user_password"]
    end

    res = query("principal-update", 
      "email" => email,
      "login" => login, 
      "password" => password,
      "first-name" => first_name,
      "last-name" => last_name,
      "send-email" => false,
      "has-children" => 0, 
      "type" => "user")

    puts "ACS: user created"
    return res.body
  end

  def delete_user(principal_id)
    puts "ACS delete user with id: " + principal_id

    res = query("principals-delete", "principal-id" => principal_id)

    puts "ACS: user deleted"
    return res.body
  end

  # create a new meeting in Adobe Connect
  # e.g. "https://collab-test.switch.ch/api/xml?action=sco-update&type=meeting&name=API-Test&folder-id=12578070&date-begin=2012-06-15T17:00&date-end=2012-06-15T23:00&url-path=apitest"
  def create_meeting(name, folder_id, url_path)
    puts "ACS create meeting with name '#{name}', folder_id '#{folder_id.to_s}' and url_path '#{url_path}'"

    res = query("sco-update", 
      "type" => "meeting", 
      "name" => name, 
      "folder-id" => folder_id, 
      "url-path" => url_path)

    puts "ACS: meeting created"
    return res.body
  end

  def delete_meeting(sco_id)
    puts "ACS delete meeting with sco_id: " + sco_id

    res = query("sco-delete", 
      "sco-id" => sco_id)

    puts "ACS: meeting deleted"
    return res.body
  end

  # searches the user with the given email address
  # e.g. "https://collab-test.switch.ch/api/xml?action=principal-list&filter-email=rfurter@ethz.ch"
  def get_principal(filter = nil, sort = nil)
    puts "ACS: get_principal"
    res = query("principal-list", 
      "filter" => filter, 
      "sort" => sort)

    return res.body
  end

  def get_my_meetings_folder(email)
    # NOTE: this id does not change unless we set up AC new
    tree_id = 14

    filter = AdobeConnectApi::FilterDefinition.new
    filter["name"] == email

    res = query("sco-contents", "sco-id" => tree_id, "filter" => filter)
    return res.body
  end

  # e.g. "https://collab-test.switch.ch/api/xml?action=permissions-update&principal-id=12578066&acl-id=13112626&permission-id=host"
  def permissions_update(principal_id, acl_id, permission_id)
    res = query("permissions-update", 
      "principal-id" => principal_id,
      "acl-id" => acl_id, 
      "permission-id" => permission_id)
    
    return res.body
  end

  #returns SCO information of sco-id
  def sco_info(sco_id)
    res = query("sco-info", "sco-id" => sco_id)
    return res.body
  end

  # sco-search-by-field&query=TB_ac_test&field=name
  def search_meeting(name)
    filter = AdobeConnectApi::FilterDefinition.new
    filter["type"] == "meeting"
    res = query("sco-search-by-field", 
      "query" => name, 
      "field" => "name", 
      "filter" => filter)
    # data = XmlSimple.xml_in(res.body)
    # scos = []
    # if data["sco-search-by-field-info"]
    #   results = data["sco-search-by-field-info"][0]
    #   scos = results["sco"]
    # end
    return res.body
  end

  #action=group-membership-update&group-id=integer&principal-id=integer&is-member=boolean
  def group_membership_update(group_id, principal_id, is_member)
    res = query("group-membership-update", 
      "group-id" => group_id, 
      "principal-id" => principal_id, 
      "is-member" => is_member)

    return res.body
  end

  def update_meeting(sco_id, description, language)
    # "action = sco-update&sco-id=&description=&lang="
    res = query("sco-update", 
      "sco-id" => sco_id, 
      "description" => description,
      "lang" => language)

    return res.body
  end




  ### STATISTIC FUNCTIONS (NOTE: NOT YET TESTED) ###

  # e.g. acl-field-update&acl-id=13117741&field-id=meeting-passcode&value=12345
  def set_passcode(acl_id, passcode)
    res = query("acl-field-update", 
      "acl-id" => acl_id, 
      "field-id" => "meeting-passcode", 
      "value" => passcode)

    data = XmlSimple.xml_in(res.body)
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], nil)
  end

  #Returns all defined quotas (untested)
  def report_quotas
    res = query("report-quota")
    data = XmlSimple.xml_in(res.body)
    rows = []
    if data["report-quotas"]
      data["report-quotas"].each do |trans|
        rows = trans["quota"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], rows)
  end

  #returns all the session of a meeting as a result object
  def report_meeting_sessions(meeting_id, filter = nil, sort = nil)
    res = query("report-meeting-sessions", "sco-id" => meeting_id, "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    rows = []
    if data["report-meeting-sessions"]
      data["report-meeting-sessions"].each do |trans|
        rows = trans["row"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], rows)
  end

  #returns all groups
  def report_groups(filter = nil, sort = nil)
    puts "ACS: Query: Groups"
    res = query("principal-list", "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    groups = []
    if data["principal-list"]
      data["principal-list"].each do |trans|
        groups = trans["principal"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], groups)

  end

  #returns all groups
  def report_memberships(group_id, filter = nil, sort = nil)
    puts "ACS: Query: Group Memberships"
    res = query("principal-list", "group-id" => group_id, "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    members = []
    if data["principal-list"]
      data["principal-list"].each do |trans|
        members = trans["principal"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], members)

  end

  # TODO KG: refactor (return res.body) and test
  #returns permission information of an sco-id
  def permissions_info(sco_id, filter = nil)
    res = query("permissions-info", "acl-id" => sco_id, "filter" => filter)

    return res.body
    data = XmlSimple.xml_in(res.body)
    if data['permissions'][0]
      return data['permissions'][0]
    end
    #puts YAML::dump(data)
#    if data["sco"][0]
#      return data["sco"][0]
#    end
  end


  #returns all SCOs as a result object
  def report_bulk_objects(filter = nil, sort = nil)
    res = query("report-bulk-objects", "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    rows = []
    if data["report-bulk-objects"]
      data["report-bulk-objects"].each do |trans|
        rows = trans["row"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], rows)
  end

  #returns all users as a result object
  def report_bulk_users(custom_fields = false, filter = nil, sort = nil)
    res = query("report-bulk-users", "custom-fields" => custom_fields, "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    rows = []
    if data["report-bulk-users"]
      data["report-bulk-users"].each do |trans|
        rows = trans["row"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], rows)
  end

  #returns all transactions as a result object
  def report_bulk_consolidated_transactions(filter = nil, sort = nil)
    res = query("report-bulk-consolidated-transactions", "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    rows = []
    if data["report-bulk-consolidated-transactions"]
      data["report-bulk-consolidated-transactions"].each do |trans|
        rows = trans["row"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], rows)
  end


  #sends a query to the server and returns the http response. Parameters,
  #filter- and sort-definitions can be added. The filter as "filter" => ... and
  #the sort as "sort" => ...
  def query(action, hash = {})
    # uri = URI.parse("https://130.59.10.31")
    # http = Net::HTTP.new(uri.host, uri.port)
    # http.use_ssl = true
    # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #
    # request = Net::HTTP::Get.new(uri.request_uri)
    #
    # response = http.request(request)
    # response.body
    # response.status
    # response["header-here"] # All headers are lowercase
    uri = URI.parse(@url + "/api/xml?action=#{action}")
    hash.each_pair do |key, val|
      if val
        if key == "filter" or key == "sort"
          uri.query += val.query
        else
          uri.query += "&" + key + "=" + CGI::escape("#{val}")
        end
      end
    end
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == "https"
       http.use_ssl=true
       http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Get.new(uri.request_uri)
    # logger = Logger.new('log/development.log')
    # logger.info(url.path + "?" + url.query)
    if @sessionid
      request.add_field("Cookie", "BREEZESESSION="+@sessionid)
    end
    puts "ACS query - request: " + request.path
    response = http.request(request)
    puts "ACS query - response: " + response.body.inspect
    return response
  end



  ### ADMIN FUNCTIONS (FOR STATISTICS) ###

  # def report-active-meetings
  #   res = query("report-active-meetings")
  #   data = XmlSimple.xml_in(res.body)
  #   return AdobeConnectAPI::Result.new(data)
  # end

end
