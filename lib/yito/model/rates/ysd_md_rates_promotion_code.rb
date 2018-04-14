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

        # -------------------------- Class methods ---------------------------------------------------------

        # Check if there are active discounts
        #
        def self.active?(date)
          count(:date_from.lte => date, :date_to.gte => date )
        end

        #
        # Check if the promotion code is valid
        #
        def self.valid_code?(promotion_code)
          if promotion_code = ::Yito::Model::Rates::PromotionCode.first(promotion_code: promotion_code)
            promotion_code.valid_code?
          else
            return false
          end
        end

        # ------------------------- Instance methods ------------------------------------------------------

        #
        # Check if the promotion code is valid
        #
        def valid_code?
          today = Date.today
          if today >= self.date_from && today <= self.date_to
            return true
          else
            return false
          end
        end

      end
    end
  end
end