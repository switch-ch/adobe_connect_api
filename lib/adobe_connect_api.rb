
# Copyright (c) 2010 SWITCH - Serving Swiss Universities
# Author: Mischael Schill <me@mschill.ch>
#         Martin Kos <martin@kos.li>
#         Christian Rohrer <christian.rohrer@switch.ch>
# $Id$

require 'rubygems'
# require "net/http"
require "net/https"
require "uri"
require 'xmlsimple'
require "cgi"
require "yaml"
#require 'logger'

require "adobe_connect_api/version"
require 'adobe_connect_api/filter_definition'
require 'adobe_connect_api/sort_definition'
require 'adobe_connect_api/result'


# This class is a simple utility to acces the adobe connect api. Before
# making any queries use the login-method
# There are dedicated methods for some of the actions of the api and a generic
# "query"-method for all the others.
# All the actions are defined in the Adobe Connect Pro API documentation
# some of the actions are accepting filter- and/or sorting-definitions.

# module AdobeConnectApi
class AdobeConnectAPI

  attr :url
  attr :pointconfig

  # return BREEZESESSION id
  def sessionid
    @sessionid
  end

  #The URL is the base URL of the Connect-Server, without the trailing slash
  def initialize (url = nil, environment, root_directory)
    #TODO ChR: Get this from the application config/initializer/abobe_connect_api.rb
    # begin
    #   environment = Rails.env
    # # KG: we need the rescue blog since belt does not know Rails, but instead uses Sinatra.env
    # rescue
    #   environment = Sinatra.env
    # end

    @pointconfig = YAML::load_file("#{root_directory}/config/config.breeze.yml")[environment]
    if (url == nil)
      @url = pointconfig["url"]
    else
      @url = url
    end
  end

  #makes the login to the server
  def login (login = nil, password = nil, account_id=nil, external_auth=nil, domain=nil)

    if (login != nil && password == nil)
      # user given --> use generic user password
      # TODO KG: generate password
      password = pointconfig["generic_user_password"]
    elsif (login == nil) && (password == nil)
       login = pointconfig["username"]
       password = pointconfig["password"]
    end

    res = query("login",
      "login" => login,
      "password" => password,
      "account-id" => account_id,
      "external-auth" => external_auth,
      "domain" => domain)

    # TODO: debug
    puts res.body.inspect

    cookies = res.response["set-cookie"]
    puts cookies.inspect
    cookies.split(";").each{|s|
      array = s.split("=")
      if array[0] == "BREEZESESSION"
        @sessionid = array[1]
      end
    }
    #puts "ACS: Logged in"
    return res.body
  end

  #makes a logout and removes the cookie
  def logout
    res = query("logout").body
    @sessionid = nil
    puts "ACS: Logged out"
    return res
  end

  # creates a new user in Adobe Connect
  def create_user(email = nil, login = nil, password = nil, first_name = nil, last_name = nil)
    # ?action=principal-update&email=string&first-name=string&has-children=boolean&last-name=string&login=string&password=string&send-email=boolean&type=allowedValue&session=BreezeSessionCookieValue
    
    # send-email: true
    # has-children: 0
    # type: user

    if password == nil
      password = pointconfig["generic_user_password"]
    end

    res = query("principal-update", 
      "email" => email,
      "login" => login, 
      "password" => password,
      "first-name" => first_name,
      "last-name" => last_name,
      "send-email" => true,
      "has-children" => 0, 
      "type" => "user")

    puts "ACS: user created"
    return res.body
  end

  # TODO KG: add host
  # create a new meeting in Adobe Connect
  def create_meeting(name, folder_id, url_path)

    if folder_id == nil
      folder_id = 12578070
    end

    puts "ACS create meeting with name, folder_id and url_path: " + name + folder_id.to_s + url_path

    res = query("sco-update", 
      "type" => "meeting", 
      "name" => name, 
      "folder-id" => folder_id, 
      "url_path" => url_path)

    puts query

    puts "ACS: meeting created"
    puts response.body
    data = XmlSimple.xml_in(response.body)
    scos = []
    if data["sco-search-by-field-info"]
      results = data["sco-search-by-field-info"][0]
      scos = results["sco"]
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], scos)
    # https://collab-test.switch.ch/api/xml?action=sco-update&type=meeting&name=API-Test&folder-id=12578070&date-begin=2012-06-15T17:00&date-end=2012-06-15T23:00&url-path=apitest
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

  #returns SCO contents of sco-id
  def sco_contents(sco_id, filter = nil, sort = nil)
    res = query("sco-contents", "sco-id" => sco_id, "filter" => filter, "sort" => sort)
    data = XmlSimple.xml_in(res.body)
    scos = []
#    puts YAML::dump(data)
    if data["scos"]
      data["scos"].each do |trans|
#        puts YAML::dump(trans)
#        puts "-------"
        scos = trans["sco"]
      end
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], scos)
  end

  #returns SCO information of sco-id
  def sco_info(sco_id)
    res = query("sco-info", "sco-id" => sco_id)
    data = XmlSimple.xml_in(res.body)
    if data["sco"][0]
      return data["sco"][0]
    end
  end

  #returns permission information of an sco-id
  def permissions_info(sco_id, filter = nil)
    res = query("permissions-info", "acl-id" => sco_id, "filter" => filter)
    data = XmlSimple.xml_in(res.body)
    puts YAML::dump(data)
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

  def search_meeting(name)
    action = "sco-search-by-field&query=" + name + "&field=name"
    uri = URI.parse(AC_HOST + "/api/xml?action=#{action}")
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == "https"
      http.use_ssl=true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Get.new(uri.request_uri)
    if @sessionid
      request.add_field("Cookie", "BREEZESESSION="+@sessionid)
    end
    puts request.path
    response = http.request(request)

    puts response.body
    data = XmlSimple.xml_in(response.body)
    scos = []
    if data["sco-search-by-field-info"]
      results = data["sco-search-by-field-info"][0]
      scos = results["sco"]
    end
    return AdobeConnectAPI::Result.new(data["status"][0]["code"], scos)
  end

  #sends a query to the server and returns the http response. Parameters,
  #filter- and sort-definitions can be added. The filter as "filter" => ... and
  #the sort as "sort" => ...
  def query(action, hash = {})
    puts action
    puts hash.inspect
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
    puts request.path
    response = http.request(request)
    return response
  end

end
