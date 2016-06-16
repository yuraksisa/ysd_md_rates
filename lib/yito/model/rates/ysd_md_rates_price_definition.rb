require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class PriceDefinition
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_price_defs' 
  	  	
  	  	property :id, Serial
  	  	property :name, String, :length => 80
        property :description, String, :length => 255
        property :max_price, Decimal, :scale => 2, :precision => 10, :default => 0
        property :base_price, Decimal, :scale => 2, :precision => 10, :default => 0
        property :type, Enum[:season, :no_season], :default => :no_season
        property :units_management, Enum[:unitary, :detailed], :default => :unitary
        property :units_management_value, Integer, :default => 1
    
        belongs_to :factor_definition, :required => false
        belongs_to :season_definition, :required => false

        has n, :prices, :child_key => [:price_definition_id], :parent_key => [:id], :constraint => :destroy      

        def save
          check_factor_definition! if self.factor_definition
          check_season_definition! if self.season_definition
          super
        end
        
        #
        # Check if the are different prices depending on the date
        #
        def season?
          type == :season
        end
        
        #
        # Check if the prices do not depend on the date
        #
        def no_season?
          type == :no_season
        end
        
        #
        # Check if there is only a price
        #
        def unitary?
          units_management == :unitary
        end
        
        #
        # Check if there are different prices depending on the units
        #
        def detailed?
          units_management == :detailed?
        end

        #
        # Get the prices for basic units (1..units_management_value)
        #
        def detailed_prices_basic_units(season=nil)
           if units_management == :detailed
             prices.select do |price| 
                if season 
                  price.units > 0 and (not price.season.nil? and price.season.id == season.id)
                else
                  price.units > 0
                end
             end 
           end 
        end
        
        #
        # Get the prices for an extra unit
        #
        def detailed_prices_extra_unit(season=nil)
           if units_management == :detailed
             data = prices.select do |price| 
                if season 
                  price.units == 0 and (not price.season.nil? and price.season.id == season.id)
                else
                  price.units == 0
                end
             end              
             data.first.price if data.size > 0
           end
        end

        #
        # Get the adjust price for extra unit
        #
        def detailed_adjust_extra_unit(season=nil)
           if units_management == :detailed
             data = prices.select do |price| 
                if season 
                  price.units == 0 and (not price.season.nil? and price.season.id == season.id)
                else
                  price.units == 0
                end
             end              
             
             data.size == 0 ? "" : (data.first.adjust_operation == ' ' ? '' : data.first.adjust_operation + " " + ("%.2f" % data.first.adjust_amount))

           end
        end
        
        #
        # Calculate the price for a day and a number of units
        #
        def calculate_price(date, units)
          if type == :season
            if units_management == :unitary
              calculate_price_season_unitary(date, units)
            else
              calculate_price_season_detailed(date, units)
            end
          else
            if units_management == :unitary
              calculate_price_no_season_unitary(units)
            else
              calculate_price_no_season_detailed(units)
            end
          end
        end 
        
        #
        # Calculate multiple prices for a date and from 1 unit to the
        # number of units
        #
        def calculate_multiple_prices(date, units)
          if type == :season
            if units_management == :unitary
              calculate_multiple_prices_season_unitary(date, units)
            else
              calculate_multiple_prices_season_detailed(date, units)
            end
          else
            if units_management == :unitary
              calculate_multiple_prices_no_season_unitary(units)
            else
              calculate_multiple_prices_no_season_detailed(units)
            end
          end
        end

        private 

        # ------------ Calculating the price --------------------------------
        
        #
        # Calculate the price when there are not different prices for seasons 
        # and the price is unitary
        # 
        def calculate_price_no_season_unitary(units)
          price = Price.first(price_definition_id: id, units: 1)
          price_value = price.nil? ? 0 : price.price * units
          price_value = price.nil? ? price_value : price.apply_adjust(price_value)
          apply_price_definition(price_value, units)
        end

        #
        # Calculate prices up to units where there are not differents prices
        # for season and the price is unitary
        #
        def calculate_multiple_prices_no_season_unitary(units)
        
          unitary_price = calculate_price_no_season_unitary(1)

          prices = (1..units).inject({}) do |result, item|
             result.store(item, item * unitary_price)
             result
          end 

          return prices

        end
        
        #
        # Calculate the price when there are not different prices for seasons
        # and the price is detailed
        #
        # NOT TESTED
        #
        def calculate_price_no_season_detailed(units)
          if units == 0
            apply_price_definition(0, units)
          elsif unit <= units_management_value
            price = Price.first(price_definition_id: id, units: unit)
            price_value = price.nil? ? 0 : price.price
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)            
            apply_price_definition(price_value, units)
          else
            price_max = Price.first(price_definition: id, units: units_management_value)
            price_extra = Price.first(price_definition: id, units: 0)
            price_value = price_max.nil? ? 0 : price_max.price
            price_value += price_extra.nil? ? 0 : (price_extra.price * (units - units_management_value))
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)
          end 
        end

        #
        # Calculate prices up to units where there are not differents prices
        # for season and the price is unitary
        #
        # NOT IMPLEMENTED
        #
        def calculate_multiple_prices_no_season_detailed(units)

        end        

        #
        # Calculate the price when there are different prices for seasons 
        # and the price is unitary
        # 
        def calculate_price_season_unitary(date, units)
          if season = season_definition.season(date)
            price = Price.first(price_definition_id: id, season_id: season.id, units: 1)
            price_value = price.nil? ? 0 : price.price * units
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)
            apply_price_definition(price_value, units)
          else
            apply_price_definition(0, units)
          end
        end

        #
        # Calculate prices up to units where there are differents prices
        # for season and the price is unitary
        #
        def calculate_multiple_prices_season_unitary(date, units)

          unitary_price = calculate_price_season_unitary(date, 1)
          
          prices = (1..units).inject({}) do |result, item|
             result.store(item, item * unitary_price)
             result
          end 
        
          return prices

        end

        #
        # Calculate the price when there are not different prices for seasons 
        # and the price is detailed
        # 
        # NOT TESTED
        #
        def calculate_price_season_detailed(date, units)

          if season = season_definition.season(date)
            if units == 0
              apply_price_definition(0, units)
            elsif units <= units_management_value
              price = Price.first(price_definition_id: self.id, season_id: season.id, units: units)
              price_value = price.nil? ? 0 : price.price
              price_value = price.nil? ? price_value : price.apply_adjust(price_value)
              apply_price_definition(price_value, units)
            else
              price_max = Price.first(price_definition_id: self.id, season_id: season.id, units: units_management_value)
              price_extra = Price.first(price_definition_id: self.id, season_id: season.id, units: 0)
              price_value = price_max.nil? ? 0 : price_max.price
              price_value += price_extra.nil? ? 0 : (price_extra.price * (units - units_management_value))
              price_value = price.nil? ? price_value : price.apply_adjust(price_value)
            end 
          else
            apply_price_definition(0, units)
          end

        end
        
        #
        # Calculate prices up to units where there are not differents prices
        # for season and the price is detailed
        #
        # NOT IMPLEMENTED
        #
        def calculate_multiple_prices_season_detailed(date, units)

        end

        #
        # Apply the factor and the max price 
        #
        def apply_price_definition(price, units)
          # Apply factor
          price *= factor_definition.factor(units) unless factor_definition.nil?
          # Add base price
          total_price = (base_price || 0) + price
          # Check max_price
          pd_max_price = (max_price || 0)
          (pd_max_price > 0) ? [total_price, pd_max_price].min : total_price
        end

        # ----------------------------------------------------------------------

        def check_factor_definition!
      
          if self.factor_definition and (not self.factor_definition.saved?) and loaded = FactorDefinition.get(self.factor_definition.id)
            self.factor_definition = loaded
          end

        end        

        def check_season_definition!
      
          if self.season_definition and (not self.season_definition.saved?) and loaded = SeasonDefinition.get(self.season_definition.id)
            self.season_definition = loaded
          end

        end        


      end
    end
  end
end