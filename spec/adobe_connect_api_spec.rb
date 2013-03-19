require 'spec_helper'

describe AdobeConnectAPI do

  it 'should return correct version string' do
    AdobeConnectAPI.version_string.should == "AdobeConnectAPI version #{AdobeConnectApi::VERSION}"
  end

  it 'should login admin' do
    interactconfig = YAML::load_file("./config/config.breeze.yml")[ENV["RAILS_ENV"]]
    url = interactconfig["url"]

    # open AdobeConnectAPI (use URL from config file)
    @acs = AdobeConnectAPI.new(url, ENV["RAILS_ENV"], nil)
    @acs.pointconfig=(interactconfig)
    # login to Adobe Connect
    res = XmlSimple.xml_in(@acs.login(), { 'KeyAttr' => 'name' })
    status = res['status'].first['code']
    status.should match "ok"
  end

end