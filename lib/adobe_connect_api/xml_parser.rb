# Copyright (c) 2010 - 2013 SWITCH - Serving Swiss Universities
# Author: Katja Gräfenhain <katja.graefenhain@switch.ch>

# This class is a simple utility to parse the result from querying the 
# adobe connect api. All methods accept a String containing XML, that is
# returned from the AdobeConnectAPI methods.
# For queries and returned results see the API documentation: 
# http://help.adobe.com/en_US/connect/8.0/webservices/connect_8_webservices.pdf
module XMLParser

  # used for all actions, e.g. 'login' and 'logout'
  def get_status_code(xml)
    data = XmlSimple.xml_in(xml)
    data['status'].first['code']
  end

  # used if the returned status contains an invalid value
  def get_invalid_subcode(xml)
    data = XmlSimple.xml_in(xml)
    data['status'].first['invalid'].first['subcode']
  end

  # supported actions: 'principal-update' or 'principal-list'
  # NOTE: does not handle more than one result, so use only for 'principal-list' that returns a unique result e.g. when querying users by e-mail
  def get_principal_id(xml)
    data = XmlSimple.xml_in(xml)
    if data.keys.include?('principal-list')
      return data['principal-list'].first['principal'].first['principal-id'] unless data['principal-list'].first.empty?
    elsif data.keys.include?('principal')
      return data['principal'].first['principal-id']
    else
      raise "XMLParser does not support result of this format. No principal information found."
    end
    return nil
  end

  # supported actions: 'sco-update', 'sco-info'
  def get_sco_id(xml)
    data = XmlSimple.xml_in(xml)
    if data['sco']
      return data['sco'].first['sco-id']
    else
      raise "XMLParser does not support result of this format. No sco information found."
    end
    return nil
  end

  # supported action: 'sco-search-by-field'
  # gets the first result that name EXACTLY matches the given name
  def get_sco_id_for_unique_name(xml, name)
    data = XmlSimple.xml_in(xml)
    if data['sco-search-by-field-info'] && !data['sco-search-by-field-info'].first.empty?
      data['sco-search-by-field-info'].first['sco'].each do |sco|
        if sco['name'].first == name
          return sco['sco-id']
        else 
          raise "No correct match for name #{name} found"
        end
      end
    end
    return nil
  end

  # supported actions: 'sco-contents' but only with filter-name and the user's e-mail-address (does not consider multiple sco results)
  # e.g. action=sco-contents&sco-id=11&filter-name=interact-support%40switch.ch
  def get_folder_id(xml)
    data = XmlSimple.xml_in(xml)

    if data['scos']
      return data['scos'].first['sco'].first['sco-id'] unless data['scos'].first.empty?
    else
      raise "XMLParser does not support result of this format. No sco information found."
    end
    return nil
  end

  def get_description(xml)
    data = XmlSimple.xml_in(xml)

    if data['sco'].first['description']
      return data['sco'].first['description']
    else
      raise "No description information found."
    end
    return nil
  end

  def get_language(xml)
    data = XmlSimple.xml_in(xml)

    if data['sco'].first['lang']
      data['sco'].first['lang']
    else
      raise "No language information found."
    end
    return nil
  end
  
end