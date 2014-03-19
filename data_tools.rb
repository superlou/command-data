#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'optparse'

require 'yaml'
require 'census_api'
require 'csv'

# Census dataset information available from:
# http://www.census.gov/prod/cen2010/doc/sf1.pdf

options = {}
OptionParser.new do |opts|
	opts.banner = "Usage: data_tools.rb [options]"

	opts.on "-c", "--cache-census", "Cache various census statistics for cities" do |c|
		options[:cache_census] = c
	end

	opts.on "-a", "--assemble-data LIMIT", "Assemble all game data" do |a|
		options[:assemble_data] = a
	end
end.parse!

if options[:cache_census]
	config = YAML.load(File.read 'config.yml')
	census_client = CensusApi::Client.new(config['census_api_key'], dataset: 'SF1')
	
	result = census_client.find('P0010001', 'PLACE')
	result = result.sort_by{|p| p["P0010001"].to_i}.reverse

	File.open('cache/city_census_population.yml', 'w') do |file|
		file.write result.to_yaml
	end

	puts "Done!"
end

if options[:assemble_data]
	gazette_file = File.open('cache/2013_Gaz_place_national.txt', 'r:ascii')
	gazette = CSV.read(gazette_file,
					   "r:ISO-8859-1:UTF-8",
					   {col_sep: "\t", headers: :first_row}
					   )

	limit = options[:assemble_data].to_i

	city_game_data = []

	city_populations = YAML.load(File.read 'cache/city_census_population.yml')
	city_populations = city_populations[0..limit]

	city_game_data = city_populations.each_with_index.map do |cp, i|
		record = {}

		g = gazette.find {|g| g["GEOID"] == "#{cp['state']}#{cp['place']}"}
		record["name"] = cp['name']
		record["state_id"] = cp["state"]
		record["place_id"] = cp["place"]
		record["population"] = cp["P0010001"].to_i
		record["lat"] = g[10].strip.to_f
		record["lon"] = g[11].strip.to_f
		puts "#{100.0 * i / limit}%"

		record
	end

	File.open('cache/city_data.yml', 'w') do |file|
		file.write city_game_data.to_yaml
	end
end
