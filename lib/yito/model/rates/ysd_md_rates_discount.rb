require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
      #
      # Represents a discount
      #
  	  class Discount
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_discount' 
  	  	
        property :id, Serial
        property :date_from, DateTime
        property :date_to, DateTime
        property :discount_type, Enum[:percentage, :amount], :default => :percentage      
        property :value, Decimal, :scale => 2, :precision => 10, :default => 0
      end
    end
  end
end