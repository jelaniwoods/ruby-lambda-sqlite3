p `ruby -e 'require "json"; require "active_record"; require "sqlite3"; require "fileutils"; require "awesome_print"; ActiveRecord::Base.establish_connection(adapter: "sqlite3",database: "msm.sqlite3"); Dir[File.join("models", "*.rb")].each do |file| require("\#{Dir.pwd}/\#{file}");  end; p "d"; p Movie.first'`
