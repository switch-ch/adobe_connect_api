require 'rspec'
require 'adobe_connect_api'

RSpec.configure do |config|
  ENV["RAILS_ENV"] = 'test'
  config.color_enabled = true
  config.formatter     = 'documentation'
end