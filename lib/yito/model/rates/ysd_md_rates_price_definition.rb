require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
      #
      # Price definition
      #
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

        property :apply_standard_price, Boolean, default: false
        property :apply_base_price, Boolean, default: false
        property :apply_max_price, Boolean, default: false
        property :apply_usage, Boolean, default: false
        property :apply_discount_by_days, Boolean, default: false


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
        #  |
        #  |- season
        #  |    |- unitary
        #  |    |- detailed
        #  |- no season
        #  |    |- unitary
        #  |    |- detailed
        #  |
        #
        # == Parameters::
        #
        # date:: The start date
        # units:: The number of units (days or hours)
        # mode:: Getting the number of days in seasons (:first_season_day or :season_days_average)
        #
        # == Returns::
        #
        # The price
        #
        def calculate_price(date, units, mode=:first_season_day)

          if type == :season
            if units_management == :unitary
              calculate_price_season_unitary(date, units, mode, discount_by_days(units))
            else
              calculate_price_season_detailed(date, units, mode, discount_by_days(units))
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
        # Calculate multiple prices for a date and from 1 unit to the number of units
        #
        #  |
        #  |- season
        #  |    |- unitary
        #  |    |- detailed
        #  |- no season
        #  |    |- unitary
        #  |    |- detailed
        #  |
        #
        # == Parameters::
        #
        # date:: The start date
        # units:: The number of units (days or hours)
        # mode:: Getting the number of days in seasons (:first_season_day or :season_days_average)
        #
        # == Returns::
        #
        # The price
        #        
        def calculate_multiple_prices(date, units, mode=:first_season_day)
          if type == :season
            if units_management == :unitary
              calculate_multiple_prices_season_unitary(date, units, mode, discount_by_days(units))
            else
              calculate_multiple_prices_season_detailed(date, units, mode, discount_by_days(units))
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

        # ---------------------- PRIVATE METHODS ----------------------------
        
        # -------------------- No season calculus ---------------------------

        #
        # Calculate the price when there are not different prices for seasons 
        # and the price is unitary
        # 
        # == Parameters::
        #
        # units:: The number of units
        #
        # == Return::
        #
        # The calculated price
        #
        def calculate_price_no_season_unitary(units)
          price = Price.first(price_definition_id: id, units: 1)
          price_value = price.nil? ? 0 : price.price * units
          price_value = price.nil? ? price_value : price.apply_adjust(price_value)
          calculated_value = apply_price_definition(price_value, units)
          return calculated_value
        end

        #
        # Calculate the price when there are not different prices for seasons
        # and the price is detailed
        # 
        # == Parameters::
        #
        # units:: The number of units
        #
        # == Return::
        #
        # The calculated price
        #
        def calculate_price_no_season_detailed(units)
          calculated_value = 0
          if units == 0
            calculated_value = apply_price_definition(0, units)
          elsif units <= units_management_value
            price = Price.first(price_definition_id: id, units: units)
            price_value = price.nil? ? 0 : price.price
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)            
            calculated_value = apply_price_definition(price_value, units)
          else
            price_max = Price.first(price_definition_id: id, units: units_management_value)
            price_extra = Price.first(price_definition_id: id, units: 0)
            price_value = price_max.nil? ? 0 : price_max.price
            price_value += price_extra.nil? ? 0 : (price_extra.price * (units - units_management_value))
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)
            calculated_value = apply_price_definition(price_value, units)
          end 
          return calculated_value
        end

        # --------------------- Season calculus ---------------------------

        #
        # Calculate the price when there are different prices for seasons 
        # and the price is unitary
        # 
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # mode:: The mode :first_season_day or :season_days_average
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #         
        def calculate_price_season_unitary(date, units, mode, discount_by_days_tp)

          if mode == :first_season_day
            calculate_price_season_unitary_first_season_day(date, units, discount_by_days_tp)
          elsif mode == :season_days_average
            calculate_price_season_unitary_season_days_average(date, units, discount_by_days_tp)
          end

        end


        #
        # Calculate the price when there are not different prices for seasons
        # and the price is detailed
        # 
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # mode:: The mode :first_season_day or :season_days_average
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #   
        def calculate_price_season_detailed(date, units, mode, discount_by_days_tp)

          if mode == :first_season_day
            calculate_price_season_detailed_first_season_day(date, units, discount_by_days_tp)
          elsif mode == :season_days_average
            calculate_price_season_detailed_season_days_average(date, units, discount_by_days_tp)
          end

        end

        # --------------------- Season calculus ---------------------------

        #
        # Calculate price : season unitary [first season day]
        # 
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #  
        def calculate_price_season_unitary_first_season_day(date, units, discount_by_days_tp)

          calculated_value = 0

          if season = season_definition.season(date)
            calculated_value = unitary_season_price(season, units)
            # Apply discount by number of days
            if season.apply_discount_by_days and discount_by_days_tp > 0
              calculated_value *= (1-(discount_by_days_tp/100.to_f)).round(2)
            end  
          else
            calculated_value = apply_price_definition(0, units)
          end

          return calculated_value

        end

        #
        # Calculate price : season unitary [season days average]
        # 
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #  
        def calculate_price_season_unitary_season_days_average(date, units, discount_by_days_tp)

          calculated_value = 0

          if seasons_days = season_definition.seasons_days(date, units)
            #p "seasons_days: #{seasons_days.inspect}"
            seasons_days.each do |season, days|
              season_value = unitary_season_price(season, days)
              # Apply discount by number of days
              if season.apply_discount_by_days and discount_by_days_tp > 0
                season_value *= (1-(discount_by_days_tp/100.to_f)).round(2)
              end                
              calculated_value += season_value
            end
          else
            calculated_value = apply_price_definition(0, units)
          end

          return calculated_value

        end

        #
        # Calculate price : season detailed [first season day]
        # 
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #  
        def calculate_price_season_detailed_first_season_day(date, units, discount_by_days_tp)

          calculated_value = 0

          if season_definition and season = season_definition.season(date)
            if units == 0
              calculated_value = 0
            elsif units <= units_management_value
              price = Price.first(price_definition_id: self.id, season_id: season.id, units: units)
              price_value = price.nil? ? 0 : price.price
              price_value = price.nil? ? price_value : price.apply_adjust(price_value)
              calculated_value = price_value
            else
              price_max = Price.first(price_definition_id: self.id, season_id: season.id, units: units_management_value)
              price_extra = Price.first(price_definition_id: self.id, season_id: season.id, units: 0)
              price_value = price_max.nil? ? 0 : price_max.price
              price_value += price_extra.nil? ? 0 : (price_extra.price * (units - units_management_value))
              price_value = price.nil? ? price_value : price.apply_adjust(price_value)
              calculated_value = price_value
            end
            # Apply discount by number of days
            if season.apply_discount_by_days and discount_by_days_tp > 0
              calculated_value *= (1-(discount_by_days_tp/100.to_f)).round(2)
            end              
          else
            calculated_value = 0
          end

          calculated_value = apply_price_definition(calculated_value, units)

          return calculated_value

        end

        #
        # Calculate price : season detailed [seasons days average]
        # 
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #  
        def calculate_price_season_detailed_season_days_average(date, units, discount_by_days_tp)

          calculated_value = 0

          seasons_days = season_definition.seasons_days(date, units)
          #p "seasons_days: #{seasons_days.inspect}"
          seasons_days.each do |season, days|
            season_price = (detailed_season_price(season, units) / units * days)
            # Apply discount by number of days
            if season.apply_discount_by_days and discount_by_days_tp > 0
              season_price *= (1-(discount_by_days_tp/100.to_f)).round(2)
            end               
            calculated_value += season_price
          end
          
          return calculated_value

        end

        # -------------------------- Helper methods -------------------------------

        #
        # Calculate price for a season and a number of units (days or hours)
        #
        def unitary_season_price(season, units)
          price = Price.first(price_definition_id: id, season_id: season.id, units: 1)
          price_value = (price.nil? or price.price.nil?) ? 0 : price.price * units
          price_value = price.nil? ? price_value : price.apply_adjust(price_value)
          calculated_value = apply_price_definition(price_value, units)

          return calculated_value
        end

        #
        # Calculate price for a season and a number of units (days or hours)
        #
        def detailed_season_price(season, units)

          calculated_value = 0

          if units == 0
            calculated_value = apply_price_definition(0, units)
          elsif units <= units_management_value
            price = Price.first(price_definition_id: self.id, season_id: season.id, units: units)
            price_value = price.nil? ? 0 : price.price
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)
            calculated_value = apply_price_definition(price_value, units)
          else
            price_max = Price.first(price_definition_id: self.id, season_id: season.id, units: units_management_value)
            price_extra = Price.first(price_definition_id: self.id, season_id: season.id, units: 0)
            price_value = price_max.nil? ? 0 : price_max.price
            price_value += price_extra.nil? ? 0 : (price_extra.price * (units - units_management_value))
            price_value = price.nil? ? price_value : price.apply_adjust(price_value)
            calculated_value = apply_price_definition(price_value, units)
          end

          return calculated_value
        end

        #
        # Get the discount by days
        #
        # == Parameters::
        #
        # units:: The number of units (days)
        #
        # == Return
        #
        # The discount percentage
        #
        def discount_by_days(units)
          discount = 0
          if self.apply_discount_by_days
            if discount_definition = DiscountByDayDefinition.first({name: 'general'}) 
              discount = discount_definition.discount(units)
            end
          end
          return discount    
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
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # mode:: The mode :first_season_day or :season_days_average
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #
        def calculate_multiple_prices_season_unitary(date, units, mode, discount_by_days_tp)

          unitary_price = calculate_price_season_unitary(date, 1, mode, discount_by_days_tp)

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
        # == Parameters::
        #
        # date:: The starting date
        # units:: The number of units
        # mode:: The mode :first_season_day or :season_days_average
        # discount_by_days_tp:: discount by days percentage
        #
        # == Return::
        #
        # The calculated price
        #
        def calculate_multiple_prices_season_detailed(date, units, mode, discount_by_days_tp)

          prices = (1..units).inject({}) do |result, item|
            result.store(item, calculate_price_season_detailed(date, item, mode, discount_by_days_tp))
            result
          end

          return prices

        end

        # ----------------------------------------------------------------------

        #
        # Apply the factor and the max price 
        #
        # == Parameters
        #
        # price:: The "calculated" price
        # units:: Number of units (days)
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
      
          if self.season_definition and (not self.season_definition.saved?) and loaded = SeasonDefinition.get(self.ysd_md_rates_price_definition.rb.id)
            self.season_definition = loaded
          end

        end        


      end
    end
  end
end