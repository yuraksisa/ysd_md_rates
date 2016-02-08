require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
      #
      # Represents a promotion code
      #
  	  class PromotionCode
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_promocodes' 
  	  	
        property :id, Serial
        property :promotion_code, String, :length => 256
        property :date_from, DateTime
        property :date_to, DateTime
        property :discount_type, Enum[:percentage, :amount], :default => :percentage      
        property :value, Decimal, :scale => 2, :precision => 10, :default => 0
      end
    end
  end
end