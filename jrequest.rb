#!/usr/bin/ruby
# jrequest.rb
# Ben Garvey
# ben@bengarvey.com
# 12/2/2012
# Description:  Takes a request for searching the budget database and returns json
#

puts "Content-type: text/html\n\n"
#puts "<html><head></head><body></body></html>"

#puts("Running request script...<br>")

require 'net/http'
require 'rubygems'
require 'json'
require 'mysql'
require 'cgi'
require 'yaml'

class Request

  def initialize
    #puts "Request object created<br>"
    @params     = Hash.new
    @andparams  = Hash.new
  
    # whitelisting our columns
    columns = Array.new
    columns = ['id', 'department_id', 'department_title', 'sub_object_title', 'sub_object_code', 'vendor_name', 'transaction_description', 'last_name', 'first_name', 'middle_initial', 'pay_class_title', 'total_expenditures'];

    # initialize hash with whitelisted column names
    columns.each do |v|
      @params[v]      = Array.new
      @andparams[v]   = Array.new
    end 

  end

  def getParams
    return @params
  end

  def getAndParams
    return @andparams
  end

  # parameters for drill down detail 
  def addAnd(column, value)
     # If we see a column we don't recognize, stop everything
    if (@andparams[column] == "")
      puts("Unrecognized column")
    else
      # We have a hash of arrays for when we have multiple criteria for one column
      @andparams[column].push(value)
    end
  end

  # parameters for select statement
  def add(column, value)
  
    # If we see a column we don't recognize, stop everything
    if (@params[column] == "")
      puts("Unrecognized column")
    else
      # We have a hash of arrays for when we have multiple criteria for one column
      @params[column].push(value)
    end

  end

  def prepare()
    statement = "select department_title as Department, year as \"Fiscal Year\", sub_object_title as \"City Sub-Object Title\", sub_object_code as \"City Sub-Object Code\", vendor_name as \"Vendor\", transaction_description as \"Transaction Description\", first_name as \"Employee First Name\", last_name as \"Employee Last Name\", middle_initial as \"Employee Middle initial\", pay_class_title as \"Pay Class Title\", total_expenditures as \"Total Expenditures\" from expenses where "

    @params.each do |key, value|
      value.each do |x|
        #puts "#{key} =>  #{x} <br>"
        if (x != "")
          statement += "lower(#{Mysql.escape_string(key.to_s)}) like '%#{Mysql.escape_string(x.to_s.downcase)}%' or "
        end
      end        
    end

    statement = statement.chomp(' or ')
    
    @andparams.each do |key, value|
      value.each do |x|
        if (x != "") 
          #puts "#{key} =>  #{x} <br>"
          if (key == "sub_object_code") 
            #puts x[0,1] + "<br>" # Wow, didn't know you couldn't use just x[0] in Ruby 1.8
            statement += "#{Mysql.escape_string(key.to_s)} like '#{Mysql.escape_string(x.to_s[0,1])}%' and "
          else
            statement += "lower(#{Mysql.escape_string(key.to_s)}) = '#{Mysql.escape_string(x.to_s.downcase)}' and "
          end
        end
      end        
    end


    statement = statement.chomp(' and ')
    statement += " order by vendor_name, last_name, first_name"
    #puts statement + "<br>"
    return statement

  end

  def query
    results = Array.new
    json = ""

    begin

      # Load in config file      
      c = YAML.load_file("config.yml")
      config = c['config']
      
      db = Mysql.new(config['server'], config['username'], config['password'], config['database'])    

      sql = self.prepare()
      res = db.query(sql)
      while row = res.fetch_hash
        results.push(row)
      end
      res.free
    rescue Mysql::Error => e
      puts "Error code: #{e.errno}"
      puts "Error message: #{e.error}"
      puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")      
    ensure
      db.close
    end

    return results.to_json
  end
  
  def test
    return "Testing the Request class <br>"
  end
  
end

###### begin script #####

#puts "Creating request object <br>"
req = Request.new

#puts "Getting input"
cgi = CGI.new
c = 0

cols = req.getParams()

# Go through input and add in the search criteria
# This lets us select multiple criteria

#req.add('id',  '36000')

#while (cgi["search#{c}"] != "")
  cols.each do |k, name|
   # puts "#{k} #{cgi["search0"]} <br>"
    req.add(k, cgi["search0"])  
  end
  c += 1
#end

if (cgi["dept"] != "") 
  req.addAnd('department_id', cgi["dept"])
end

if (cgi["cat"] != "") 
  req.addAnd('sub_object_code', cgi["cat"])
end

if (cgi["desc"] != "")
  req.addAnd('sub_object_title', cgi["desc"])
end

#req.add('id', '36000')
puts req.query()

