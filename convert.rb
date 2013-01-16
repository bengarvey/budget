# convert.rb
# Ben Garvey
# ben@bengarvey.com
# 11/10/2012
# Description:  Converts a CSV file to json for use in a D3 treemap.
# Writing this for the philadelphia transparent budget project
#

require 'csv'
require 'json'

# Class for storing each record in the csv
class BudgetItem

  attr_accessor :name, :size, :children, :year, :department_title, :department_id, :sub_object_title, :sub_object_code, :vendor_name, :transaction_description, :last_name, :first_name, :middle_initial, :pay_class_title, :total_expenditures  
  def initialize
    @children = Array.new
    @size = 0
  end

  # Method for generating a mysql insert script
  def to_sql

    # Hide Amex numbers
    if (@transaction_description != nil && @vendor_name  == "AMERICAN EXPRESS" || @vendor_name == "BANK OF AMERICA") 
      @transaction_description.gsub!(/\*.*\*/, "");
    end

    

    return "INSERT INTO expenses (`created`, `year`, `department_title`, `department_id`, `sub_object_title`, `sub_object_code`, `vendor_name`, `transaction_description`, `last_name`, `first_name`, `middle_initial`, `pay_class_title`, `total_expenditures`) VALUES (NOW(), '#{@year}','#{@department_title.to_s.gsub(/\\/,'\&\&').gsub(/'/,"''")}', '#{@department_id}', '#{@sub_object_title.to_s.gsub(/'/, "''")}', '#{@sub_object_code}', '#{@vendor_name.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")}', '#{@transaction_description.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")}', '#{@last_name.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")}', '#{@first_name.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")}', '#{@middle_initial.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")}', '#{@pay_class_title.to_s.gsub(/\\/, '\&\&').gsub(/'/, "''")}', #{@total_expenditures.gsub(/,/, "")});"
  end

  # Method for converting the data structure to JSON
  # Recursively calls itself until it runs out of child nodes to get JSON from
  # Accepts a string called tab that helps produce proper indenting in the json
  def getJSON(tab)

    # All nodes get a name.  Native support for to_json in Ruby is awesome, btw
    json = "#{tab}{\t\"name\" : #{name.to_json},\n"
  
    if (department_id.to_json != "null") 
      json += "#{tab}\t\"dept_id\" : #{department_id.to_json},\n"
    end

     if (sub_object_code.to_json != "null") 
      json += "#{tab}\t\"sub_object_code\" : #{sub_object_code.to_json},\n"
    end


 
    # I think we fixed this, but sometimes we were getting null values for size, so we're checking before we add the value line
    # The D3 examples I based this off used both size and value for the amount in the tree, that's why they aren't consistent.  I'll fix that later.
    if (size.to_json != "null") 
      json += "#{tab}\t\"value\" : #{size.to_json},\n"
    end

    # If we have kids, add them to the json
    if (children.count > 0)

      #json = json.chom  
      json += "#{tab}\t\"children\" : [\n"
        
      # Our recursive call with a couple of extra tabs.  Two seemed better than one.
      children.each do |kid|
        json += kid.getJSON("\t\t" + tab) 
      end 
      
      # Chomp off the trailing comma.  There's probably a Ruby method for cutting off the comma without removing the newline.  Need to google that
      json = json.chomp(",\n") + "\n"

      # Close the json array
      json += "\n#{tab}\t]\n"

    else
      # No kids, so close up shop
      json = json.chomp(",\n")
      json += "\n"
    end

    # Doing this recursively, I'm not sure how to pass it back and not have a comma at the very end.  Currently chomping it when I call it at the end of the script.
    # I could always check for how many tabs I have, but that seems sort of wrong.
    json += "#{tab}},\n"
    
    return json
  end

end

# Class that knows how to convert a collection of budgetitems into various formats
class BudgetPrinter

  attr_accessor :count

  def initialize
    @count = 0
    @filecount = 0
  end

  # Clears SQL file for writing
  def clearSQL(fc)
    File.open("data/insert-#{fc}.sql", 'w') do |file|
      file.puts("")
    end
  end

  # Adds a line to SQL file
  def addSQL(statement)
    
    if (@count % 250000 == 0)
      @filecount += 1
      self.clearSQL(@filecount)
      puts "Now writing to insert-#{@filecount}.sql"
    end

    File.open("data/insert-#{@filecount}.sql", 'a') do |file|
      file.puts(statement)
      @count += 1
    end
  end

  # Accepts a budget item and returns a json structure for the budget data
  def writeJSONToFile(b)
    count = 0
    File.open('data/all.json', 'w') do |json|  
      json.puts b.getJSON("\t").chomp(",\n")
    end
  end

end


##### START OF SCRIPT #####

# Sub Objects Code translations for city budgets
suc = Hash.new
suc['100'] = "Personal Services and Fringe Benefits"
suc['200'] = "Purchase of Services"
suc['300'] = "Materials and Supplies"
suc['400'] = "Equipment"
suc['500'] = "Contributions, Indemnities, and Taxes"
suc['700'] = "Debt Service"
suc['800'] = "Payments to Other Funds"
suc['900'] = "Advances / Misc. Payments"

# Department title translations
dept = Hash.new
dept['1'] = 'City Council'
dept['3'] = 'Mayor\'s Office-Labor Relations'
dept['4'] = 'Office Of Innovation & Technology'
dept['5'] = 'Mayor\'s Office'
dept['6'] = 'Office Of Housing'
dept['8'] = 'Mayor\'s Office Of Community Services'
dept['10'] = 'Managing Director\'s Office'
dept['11'] = 'Police Department'
dept['12'] = 'Streets Department'
dept['13'] = 'Fire Department'
dept['14'] = 'Department Of Public Health'
dept['15'] = 'Office Of Behavioral Health'
dept['16'] = 'Recreation Department'
dept['17'] = 'Fairmount Park Commission'
dept['18'] = 'Atwater Kent Museum'
dept['20'] = 'Public Property'
dept['22'] = 'Department Of Human Services'
dept['23'] = 'Prisons'
dept['24'] = 'Office Of Supportive Housing'
dept['25'] = 'Fleet Management'
dept['26'] = 'Department Of Licenses & Inspections'
dept['27'] = 'Board Of Licenses & Inspections Review'
dept['29'] = 'Board Of Building Standards'
dept['30'] = 'Zoning Board Of Adjustment'
dept['31'] = 'Department Of Records'
dept['32'] = 'Historical Commission'
dept['32'] = 'Phila. Historical Commission'
dept['34'] = 'Art Museum'
dept['35'] = 'Department Of Finance'
dept['36'] = 'Revenue Department'
dept['37'] = 'Sinking Fund Commission'
dept['38'] = 'Procurement Department'
dept['40'] = 'City Treasurer'
dept['41'] = 'City Representative Office'
dept['42'] = 'Commerce'
dept['44'] = 'Law Department'
dept['45'] = 'Board Of Ethics'
dept['46'] = 'Mayor\'s Office Of Transportation'
dept['47'] = 'Youth Commission'
dept['48'] = 'Office Of The Inspector General'
dept['50'] = 'Mural Arts Program'
dept['51'] = 'City Planning Commission'
dept['52'] = 'Free Library Of Phila.'
dept['54'] = 'Human Relations Commission'
dept['55'] = 'Civil Service Commission'
dept['56'] = 'Personnel Department'
dept['57'] = 'Zoning Code Commission'
dept['58'] = 'Office Of Arts & Culture'
dept['59'] = 'Office Of Property Assessments'
dept['61'] = 'City Controller\'s Office'
dept['63'] = 'Board Of Revision Of Taxes'
dept['68'] = 'Register Of Wills'
dept['69'] = 'District Attorney\'s Office'
dept['70'] = 'Sheriff'
dept['73'] = 'City Commissioners'
dept['84'] = 'First Judicial District'




budget = BudgetItem.new
budget.name = "Philadelphia General Fund Budget Fiscal Year 2012"

# Can limit the number of records we look at.  Useful for debugging
limit   = 300000
count   = 0

allownegatives = true

# We we generating sql or JSON?
sql = true
 
if (sql) 
  bp = BudgetPrinter.new
  bp.clearSQL(0)
end

# Load in csv file
CSV.foreach("data/philadelphia-2012-budget.csv") do |row|
#CSV.foreach("data/full_table.csv") do |row|

  if (count < limit)
  
    if (count % 1000 == 0)
      puts "#{count} complete"
    end

    # First load in all the budget data and names
    b = BudgetItem.new
    b.size = row[11].to_s.gsub(/\,/,"")
    b.children = Array.new

    # Fix the annoying "-"
    row.each do |i|
      if (i == "-") 
        i = ""
      end
    end

    b.year                      = row[0]
    b.department_id             = row[1]
    b.department_title          = row[2]
    b.sub_object_code           = row[3]
    b.sub_object_title          = row[4]
    b.vendor_name               = row[5]
    b.transaction_description   = row[6]
    b.last_name                 = row[7]
    b.first_name                = row[8]
    b.middle_initial            = row[9]
    b.pay_class_title           = row[10]
    b.total_expenditures        = row[11]
 

   
    # Some have parenthesis.  Change them to negative numbers
    if b.size[0] == "("
      b.size[0] = "-"
      b.size[-1] = ""
    end

    if (sql)
      bp.addSQL(b.to_sql)
    else

      if (b.size.to_f > 0 || allownegatives)

        # Set the name of the node
        b.name = row[7].to_s + " " + row[8].to_s + " " + row[9].to_s + " " + row[10].to_s + " " + row[11].to_s + " " + row[12].to_s
        
        primary   = "#{dept[row[1]]}"
        # The script is getting the 4th item of the row array and looking at the first character
        secondary = row[3][0] + "00" # Changes the subobject code to the code type, (e.g. 125 becomes 200)    

        # Now translate it into the proper sub object code
        secondary = "Class #{secondary}: #{suc[secondary]}";

        tertiary  = row[4]
        
        # Now we're consolidating all detailed values
        b.name = tertiary
        
        foundprimary = false
        foundsecondary = false
        foundtertiary = false

        parent = ""
        
        # Skip anything with a blank value
        if (b.size != "")

        # This part of the script is a little funky.  
        # We look through the tree to see if we have seen this combination of primary, secondary, and tertiary nodes before.  
        # Many times we will find just one or two, but not all three.
        # If we don't find all three, there is some code below to create the new ones and add in the node.       
    
          # Now see if we have a place for it yet
          budget.children.each do |kid|
            if kid.name == primary
              #puts "Found primary #{kid.name} = #{primary}"
              foundprimary = true
              kid.department_id = b.department_id
              parent = kid

              # We found the correct parent, now check for this item's children
              kid.children.each do |k|
                if k.name == secondary
               # puts "Found Secondary #{k.name} = #{secondary}"
                    foundsecondary = true
                    parent = k
                    k.sub_object_code = row[3][0] + "00" 
                    
                    # We found the correct parent, now check for this item's children
                    k.children.each do |k2|
                      if k2.name == tertiary
                       # puts "Found tertiary #{k2.name} = #{tertiary}"
                        foundtertiary = true
                        parent = k2
                                           
                        # Don't think I need this conditional anymore
                        if b.name == k2.name

                          # This should be fixed, now but sometimes we were getting empty strings
                          if k2.size.to_s == "" 
                            k2.size = 0
                          end
                          
                          # Take this individual record and add it to the tertiary category
                          k2.size += b.size.to_f
                        end

                      end

                    end   

                  end

                end

              end

            end

            # If not found, add it to the main
            if !foundprimary
              p = BudgetItem.new
              s = BudgetItem.new
              t = BudgetItem.new

              p.name = primary
              s.name = secondary
              t.name = tertiary

              p.children = Array.new
              s.children = Array.new
              t.children = Array.new

              #puts "New primary. Adding #{primary} #{secondary} #{tertiary}"
              budget.children.push(p)
              p.children.push(s)
              s.children.push(t)
              #t.children.push(b)
              t.size += b.size.to_f

              # Also have to set the sub_object_code
              s.sub_object_code = row[3][0] + "00"

            end

            # if we never found this secondary, add it to the parent we found
            if foundprimary && !foundsecondary
              s = BudgetItem.new
              t = BudgetItem.new
              s.name = secondary
              t.name = tertiary
              s.children = Array.new
              t.children = Array.new

              # Also have to set the sub_object_code
              s.sub_object_code = row[3][0] + "00"

              #puts "New secondary. Adding #{secondary} #{tertiary}"

              parent.children.push(s)
              s.children.push(t)
              t.size += b.size.to_f
              #t.children.push(b)
              
            end

            # if we never found this tertiary, add it to the parent we found
            if foundprimary && foundsecondary && !foundtertiary
              t = BudgetItem.new
              t.name = tertiary
              t.children = Array.new
        
             # puts "New tertiary.  Adding #{tertiary}"
              parent.children.push(t)
              t.size += b.size.to_f
              #t.children.push(b)
            end

            #if (parent.class.to_s != "String")
            #  puts "Children:  #{parent.children.count}"
            #end 

            # Reset these for the next round
            foundprimary    = false
            foundsecondary  = false
            foundtertiary   = false
        
          end

       end

    end

    count += 1
  end

  end
  

  if (!sql)
    # Now that we built out budget object, create the budget printer and write to file
    bp = BudgetPrinter.new
    bp.writeJSONToFile(budget)
  end
