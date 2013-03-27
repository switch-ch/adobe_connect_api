# This class is a simple utility to parse the result from querying the 
# adobe connect api. All methods accept a String containing XML, that is
# returned from the AdobeConnectAPI methods.
module XMLParser

  def get_status_code(xml)
    data = XmlSimple.xml_in(xml)
    data['status'].first['code']
  end

  def get_subcode_invalid(xml)
    data = XmlSimple.xml_in(xml)
    data['status'].first['invalid'].first['subcode']
  end

  # use only if the xml can contain only one result, e.g. after querying a principal by email
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

  # TODO KG: decide how to handle results with multiple answer possibilities
  def get_sco_id(xml)
    data = XmlSimple.xml_in(xml)
    if data['sco-search-by-field-info']
      return data['sco-search-by-field-info'].first['sco'].first['sco-id'] unless data['sco-search-by-field-info'].first.empty?
    elsif data['sco']
      return data['sco'].first['sco-id']
    else
      raise "XMLParser does not support result of this format. No sco information found."
    end
    return nil
  end

  def get_folder_id(xml)
    data = XmlSimple.xml_in(xml)
    puts data.inspect

    if data['scos']
      return data['scos'].first['sco'].first['sco-id'] unless data['scos'].first.empty?
    else
      raise "XMLParser does not support result of this format. No sco information found."
    end
    return nil

#     scos = []
# #    puts YAML::dump(data)
#     if data["scos"]
#       data["scos"].each do |trans|
# #        puts YAML::dump(trans)
# #        puts "-------"
#         scos = trans["sco"]
#       end
#     end
#     return AdobeConnectAPI::Result.new(data["status"][0]["code"], scos)

#     if res.rows.empty?
#       return nil
#     else
#       # should not contain more than 1 result
#       return res.rows.first["sco-id"]
#     end
  end
  
end