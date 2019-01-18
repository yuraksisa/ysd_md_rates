require 'data_mapper' unless defined?DataMapper::Resource

module Yito
  module Model
  	module Rates
  	  class Season
  	  	include DataMapper::Resource

        storage_names[:default] = 'rateds_seasons' 
  	  	
        property :id, Serial
        property :name, String, :length => 80
        property :from_day, Integer
        property :from_month, Integer
        property :to_day, Integer
        property :to_month, Integer
        property :min_days, Integer, default: 1
        property :apply_discount_by_days, Boolean, default: true

        belongs_to :season_definition
        
        def to_s
          "#{from_month.to_s.rjust(2, '0')}/#{from_day.to_s.rjust(2, '0')}-#{to_month.to_s.rjust(2, '0')}/#{to_day.to_s.rjust(2, '0')}"
        end

        def save
          check_season_definition! if self.season_definition
          super
        end

        #
        # Calculate the number of days of a season
        #
        def days(date_from, days)

          date_to = date_from + days

          from_year = date_from.year
          to_year = from_month <= to_month ? from_year : from_year + 1

          season_from_date = Date.civil(from_year, from_month, from_day)
          season_to_date = Date.civil(to_year, to_month, to_day)

          # It should be considered in the next year from the date_from
          if season_to_date < date_from 
            season_from_date = Date.civil(from_year+1, from_month, from_day)
            season_to_date = Date.civil(from_year+1, to_month, to_day)
          end
          
          result = 0

          if Season.included_in_period?(season_from_date, season_to_date, date_from, date_to)
            c_from = [season_from_date, date_from].max()
            c_to = [season_to_date, date_to].min()
            result = (c_to - c_from).to_i
            if (date_to > season_to_date)
              result += 1
            end
          end

          return result

        end

        private 

        def self.included_in_period?(period_start_date, period_end_date, date_from, date_to)

          (date_to >= period_start_date and date_to <= period_end_date) or
          (date_from >= period_start_date and date_from <= period_end_date) or
          (date_from >= period_start_date and date_to <= period_end_date) or
          (date_from <= period_start_date and date_to >= period_end_date)

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