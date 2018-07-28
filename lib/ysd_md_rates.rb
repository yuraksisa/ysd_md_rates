require 'yito/model/rates/ysd_md_rates_season_definition'
require 'yito/model/rates/ysd_md_rates_factor_definition'
require 'yito/model/rates/ysd_md_rates_price_definition'
require 'yito/model/rates/ysd_md_rates_season'
require 'yito/model/rates/ysd_md_rates_factor'
require 'yito/model/rates/ysd_md_rates_price'
require 'yito/model/rates/ysd_md_rates_promotion_code'
require 'yito/model/rates/ysd_md_rates_discount'

module Yito
  module Model
  	module Rates
	  extend Yito::Translation::ModelR18

	  def self.r18n(locale=nil)
	    path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'i18n'))
	    if locale.nil?
	      check_r18n!(:rates_r18n, path)
	    else
	      R18n::I18n.new(locale, path)
	    end
	  end
	  
	end
  end	  
end  