require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
      #
      # Represents a promotion code
      #
      #
  	  class PromotionCode
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_promocodes' 
  	  	
        property :id, Serial
        property :promotion_code, String, :length => 256, :unique_index => :promotion_code_unique_index
        property :date_from, DateTime
        property :date_to, DateTime
        property :source_date_from, DateTime
        property :source_date_to, DateTime        
        property :discount_type, Enum[:percentage, :amount], :default => :percentage      
        property :value, Decimal, :scale => 2, :precision => 10, :default => 0

        # -------------------------- Class methods ---------------------------------------------------------

        #
        # Check if the promotion code is valid
        #
        # == Params
        #
        # promotion_code::
        #
        #  The promotion code
        # 
        # from::
        #
        #  Source date from
        #
        # to::
        #
        #  Source date to        
        #
        def self.valid_code?(promotion_code, from=nil, to=nil)

          if promotion_code = ::Yito::Model::Rates::PromotionCode.first(promotion_code: promotion_code)
            promotion_code.valid_code?(from, to)
          else
            return false
          end

        end

        # ------------------------- Instance methods ------------------------------------------------------

        #
        # Check if the promotion code is valid
        #
        # == Params
        # 
        # from::
        #
        #  Source date from
        #
        # to::
        #
        #  Source date to
        #
        def valid_code?(from=nil, to=nil)

          today = Date.today

          if from.nil?
            from = self.source_date_from
          end
          
          if to.nil?
            to = self.source_date_to
          end    

          if today >= self.date_from and today <= self.date_to and # The current date
             from >= self.source_date_from and to <= self.source_date_to # The source date
            return true
          else
            return false
          end

        end

      end
    end
  end
end