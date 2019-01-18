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

        # Standard price (not used)
        property :standard_price, Decimal, :scale => 2, :precision => 10, :default => 0
        # Base price: It's always added to the rate
        property :base_price, Decimal, :scale => 2, :precision => 10, :default => 0
        # Max price : If the calculated price is higher that it, it's adjusted to this value
        property :max_price, Decimal, :scale => 2, :precision => 10, :default => 0

        # Specific prices for season or not
        property :type, Enum[:season, :no_season], :default => :no_season
        
        # Prices are measured in days and/or hours
        property :time_measurement_days, Boolean, default: true
        property :time_measurement_hours, Boolean, default: false

        # Units : 1 unit or a set of units (1-2-3-4-5-6-7 days)
        property :units_management, Enum[:unitary, :detailed], :default => :unitary
        property :units_management_value, Integer, :default => 1
        property :units_management_value_hours_list, String, length: 200, default: '1' # comma-separated values
        property :units_management_value_hours_half_day, Integer, default: 4

        # Daily usage extra cost (for transport products)
        # Less than <daily_usage_units_days> days
        # More than <daily_usage_units_limit> kms/miles
        # Will pay <daily_usage_units_usage_units_price> for km/mile
        property :daily_usage_units_days, Integer, default: 0
        property :daily_usage_units_limit, Integer, default: 0
        property :daily_usage_units_usage_units_price, Decimal, scale: 2, precision: 10, default: 0
  

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

        # ------------ Calculating price --------------------------------
        
        #
        # Calculate the price for a day and a number of units
        #
        def calculate_price(date, units, mode=:first_season_day)
          if type == :season
            if units_management == :unitary
              calculate_price_season_unitary(date, units, mode)
            else
              calculate_price_season_detailed(date, units, mode)
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
        # NOTE: Not full implemented
        #
        def calculate_multiple_prices(date, units, mode=:first_season_day)
          if type == :season
            if units_management == :unitary
              calculate_multiple_prices_season_unitary(date, units, mode)
            else
              calculate_multiple_prices_season_detailed(date, units, mode)
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

        # -------------------------------------------------------------------------------
        
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
        # Calculate the price when there are not different prices for seasons
        # and the price is detailed
        #
        def calculate_price_no_season_detailed(units)
          if units == 0
            apply_price_definition(0, units)
          elsif units <= units_management_value
            price = Price.first(price_definition_id: id, units: units)
            price_value = price.nil? ? 0 : price.price
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)            
            apply_price_definition(price_value, units)
          else
            price_max = Price.first(price_definition_id: id, units: units_management_value)
            price_extra = Price.first(price_definition_id: id, units: 0)
            price_value = price_max.nil? ? 0 : price_max.price
            price_value += price_extra.nil? ? 0 : (price_extra.price * (units - units_management_value))
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)
          end 
        end

        # ----------------------------------------------------------------------------------------------

        #
        # Calculate the price when there are different prices for seasons 
        # and the price is unitary
        # 
        def calculate_price_season_unitary(date, units, mode)

          if mode == :first_season_day
            calculate_price_season_unitary_first_season_day(date, units)
          elsif mode == :season_days_average
            calculate_price_season_unitary_season_days_average(date, units)
          end

        end


        #
        # Calculate the price when there are not different prices for seasons
        # and the price is detailed
        #
        def calculate_price_season_detailed(date, units, mode)

          if mode == :first_season_day
            calculate_price_season_detailed_first_season_day(date, units)
          elsif mode == :season_days_average
            calculate_price_season_detailed_season_days_average(date, units)
          end

        end

        #
        # Calculate price : season unitary [first season day]
        #
        def calculate_price_season_unitary_first_season_day(date, units)

          if season = season_definition.season(date)
            unitary_season_price(season, units)
          else
            apply_price_definition(0, units)
          end

        end

        #
        # Calculate price : season unitary [season days average]
        #
        def calculate_price_season_unitary_season_days_average(date, units)

          total_price = 0

          if seasons_days = season_definition.seasons_days(date, units)
            p "seasons_days: #{seasons_days.inspect}"
            seasons_days.each do |season, days|
              total_price += unitary_season_price(season, days)
            end
          else
            total_price = apply_price_definition(0, units)
          end

          return total_price

        end

        #
        # Calculate price : season detailed [first season day]
        #
        def calculate_price_season_detailed_first_season_day(date, units)

          if season_definition and season = season_definition.season(date)
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
        # Calculate price : season detailed [seasons days average]
        #
        def calculate_price_season_detailed_season_days_average(date, units)

          total_price = 0

          seasons_days = season_definition.seasons_days(date, units)
          #p "seasons_days: #{seasons_days.inspect}"
          seasons_days.each do |season, days|
            season_price = (detailed_season_price(season, units) / units * days)
            #p "season #{season.name} #{"%.2f" % season_price}"
            total_price += season_price
          end
          
          return total_price

        end

        #
        # Helper method
        #
        def unitary_season_price(season, units)
          price = Price.first(price_definition_id: id, season_id: season.id, units: 1)
          price_value = (price.nil? or price.price.nil?) ? 0 : price.price * units
          price_value = price.nil? ? price_value : price.apply_adjust(price_value)
          apply_price_definition(price_value, units)
        end

        #
        # Helper method
        #
        def detailed_season_price(season, units)

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

        end

        # ---------------- Calculating multiple prices ---------------------------------

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
        # Calculate prices up to units where there are not differents prices
        # for season and the price is unitary
        #
        #
        def calculate_multiple_prices_no_season_detailed(units)

          prices = (1..units).inject({}) do |result, item|
            result.store(item, calculate_price_no_season_detailed(item))
            result
          end

          return prices

        end

        #
        # Calculate prices up to units where there are differents prices
        # for season and the price is unitary
        #
        def calculate_multiple_prices_season_unitary(date, units, mode)

          unitary_price = calculate_price_season_unitary(date, 1, mode)

          prices = (1..units).inject({}) do |result, item|
            result.store(item, item * unitary_price)
            result
          end

          return prices

        end

        #
        # Calculate prices up to units where there are not differents prices
        # for season and the price is detailed
        #
        # NOT IMPLEMENTED
        #
        def calculate_multiple_prices_season_detailed(date, units, mode)

          prices = (1..units).inject({}) do |result, item|
            result.store(item, calculate_price_season_detailed(date, item, mode))
            result
          end

          return prices

        end

        # ----------------------------------------------------------------------

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