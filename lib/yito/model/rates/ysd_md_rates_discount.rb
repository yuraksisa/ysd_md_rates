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
        property :source_date_from, DateTime
        property :source_date_to, DateTime
        property :discount_type, Enum[:percentage, :amount], :default => :percentage      
        property :value, Decimal, :scale => 2, :precision => 10, :default => 0
        
        # Check if there are active discounts
        #
        def self.active?(date)
          count(:date_from.lte => date, :date_to.gte => date )
        end
        
        # Get the active discounts at a date
        #
        def self.active(date)
          all(:date_from.lte => date, :date_to.gte => date)
        end
        
      end
    end
  end
end