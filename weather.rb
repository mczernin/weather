require 'forecast_io'
require 'yaml'


class Weather
  CONTENT_URL = "http://free.worldweatheronline.com/feed/weather.ashx?"
  
  # Wishful thinking :(
  SAMPLE_DATA = {:location => "London", :address=>"London", :weather_image => "sunny", :weather_description => "Sunny throughout the day.", :min => 20, :max => 24, :units => "C"}
  
  def self.api_key
    
    # If there is an env variable with the key, use that, else look in config.yml
    if ENV['WEATHER_KEY'] != nil
      return ENV['WEATHER_KEY']
    else
      config = YAML.load_file('./config.yml')
      return config['weather_api_key']
    end
  end
  
  # location is a lat lon string like '51.5229965,-0.08712990000003629'
  # address is a string describing the address
  # scale is 'celsius' or 'farenheit'.
  def self.fetch_data location, address, scale, is_test=false
    return SAMPLE_DATA if is_test

    latlon = location.split(',')
    params = {units: 'uk'} # temp in C, speed in mph
    if scale == 'farenheit'
      params[:units] = 'us' # temp in F, speed in mph
    end

    params[:exclude] = 'minutely,hourly,flags'

    ForecastIO.api_key = api_key

    begin 
      forecast = ForecastIO.forecast(latlon[0], latlon[1], params: params)
    rescue
      raise NetworkError, "Something went wrong fetching forecast"
    end

    if forecast.nil?
      raise NetworkError, "No forecast data returned"
    end

    if scale == 'fahrenheit'
      units = 'F'
    else
      units = 'C'
    end

    forecasts = { 
      # Could also use:
      # forecast['daily']['summary']: "Light rain off-and-on until Friday; temperatures peaking at 23° on Sunday."
      # forecast['daily']['data'][0]['windSpeed']: 5.39
      # forecast['daily']['data'][0]['windBearing']: 284
      # forecast['daily']['data'][0]['humidity']: 0.62
      :location => location,
      :address => address,
      :weather_image => extract_condition(
                                  forecast['daily']['data'][0]['icon'],
                                  forecast['daily']['data'][0]['precipIntensity']),
      :weather_description => forecast['daily']['data'][0]['summary'],
      :min => forecast['daily']['data'][0]['temperatureMin'],
      :max => forecast['daily']['data'][0]['temperatureMax'],
      :precip_type => forecast['daily']['data'][0]['precipType'],
      :precip_probability => forecast['daily']['data'][0]['precipProbability'],
      :units => units
    }

    forecasts
  end

  # Translating Forecast's icon names and precipitation intensity into the 
  # icons we already had which we used with WorldWeatherOnline.
  def self.extract_condition(icon, precip_intensity) 

    case icon
    when 'clear-day'
      'sunny'

    when 'clear-night'
      'sunny'

    when 'rain'
      if precip_intensity <= 0.002
        'light_showers'
      elsif precip_intensity <= 0.017
        'light_rain'
      elsif precip_intensity <= 0.1
        'heavy_showers'
      else
        'heavy_rain'
      end

    when 'snow'
      if precip_intensity <= 0.002
        'light_snow_showers'
      elsif precip_intensity <= 0.017
        'light_snow'
      elsif precip_intensity <= 0.1
        'heavy_snow_showers'
      else
        'heavy_snow'
      end

    when 'sleet'
      if precip_intensity <= 0.1
        'sleet_showers'
      else
        'sleet'
      end

    when 'wind'
      # TODO
      'blank_icon'

    when 'fog'
      'fog'

    when 'cloudy'
      'heavy_cloud'

    when 'partly-cloudy-day'
      'sunny_intervals'

    when 'partly-cloudy-night'
      'sunny_intervals'

    when 'thunderstorm'
      'thunder'

    else
      'blank_icon'
    end
  end



  # Check that the location that has been given by the user is one worldweatheronline understands
  def self.location_is_valid location

    validation_url = "http://www.worldweatheronline.com/feed/search.ashx?query=#{location}&num_of_results=1&format=json&key=#{Weather::api_key}"

    begin
      weather = RestClient.get(validation_url)
    rescue RestClient::ServiceUnavailable
      raise NetworkError, "ServiceUnavailable was received from #{validation_url}"
    rescue Timeout::Error
      raise NetworkError, "Connection to #{validation_url} timed out!"
    end
    
    begin
      weather_content =  JSON.parse(weather)
    rescue 
      raise PermanentError, 'there was an error parsing the JSON'
    end
    
    if weather_content['search_api'].nil?
      return false
    else
      return true
    end
  end
end

class PermanentError < StandardError; end
class NetworkError < StandardError; end
  
