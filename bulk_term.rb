=begin
  Steps:
      1. Download xlsx
      2. Open file locally
      3. Remove all columns EXCEPT for the ones listed below, and change column headers to match
              last_name
              first_name
              ssn
              termdate
      4. Remove all additional header rows
      5. Name the sheet as follows:
              yyyymm_bulk_term
              example: 202411_bulk_term
      6. Remove passwords from sheet/book
      7. Save file with same name as tab from above
      8. Upload spreadsheet to tmp folder on Pod
      9. Run script on same Pod
      10. Save errors from output, obfuscate SSNs
=end
$VERBOSE = nil       

def house_bulk_term(file_date:, dry_run: false)
  if dry_run
    puts "\e[33m============= DRY-RUN ONLY =============\e[0m"
  else
    puts "\e[31m============= WARNING: LIVE RUN INITIATED =============\e[0m"
  end
 
  #########################
  # Configuration
  #########################
  date_format  =  '%m/%Y'
  file_path    =  "/enroll/tmp" 
  fein         =  "__________" 
  #########################

  # Sets up actual dates and filenames based on file_date
  actual_date  =  Date.strptime(file_date, date_format)
  year_month   =  actual_date.strftime('%Y%m')
  month_abbr   =  actual_date.strftime('%b').downcase
  base_name    =  year_month +"_" + month_abbr + "_house_bulk_term" 

  file_name    =  "#{base_name}.xlsx" 
  sheet_name   =  base_name

  # Load the spreadsheet
  begin
    workbook   =  Roo::Spreadsheet.open("#{file_path}/#{file_name}")
    sheet_data =  workbook.sheet(0)
  rescue StandardError => e
    puts "Error opening spreadsheet: #{e.message}" 
    return
  end

  # Fetch organization data
  organization = BenefitSponsors::Organizations::Organization.find_by(fein: fein)
  unless organization
    puts "Organization with fein #{fein} not found. House fein should be ________." 
    return
  end

  # Create and validate header row
  header_row = sheet_data.row(1)

  puts "\n\nHeader row should read:
  **********************************************
  [\"last_name\", \"first_name\", \"ssn\", \"termdate\"]
  **********************************************\n\n" 
  puts "Actual Header Row:
  ##############################################
  \e[32m#{header_row}\e[0m
  ##############################################
  " 
  puts "\n\n**********************************************" 
  puts "Please verify header row above and press ENTER to continue when ready." 
  STDIN.gets
  puts "Continuing....." 

  # Assign headers from the first row of the sheet
  headers = {}
  header_row.each_with_index { |header, i| headers[header.to_s.underscore.split.join.strip] = i }

  # Validate first data row
  begin
    row_info = sheet_data.row(2)
    puts "Validation Check - Row 1: #{row_info}" 
  rescue StandardError => e
    puts "Error accessing validation row: #{e.message}" 
  end

  puts "Please verify first data row above with the spreadsheet and press ENTER to continue." 
  STDIN.gets
  puts "Continuing..." 

  last_row             =  sheet_data.last_row
  all_census_employees =  CensusEmployee.by_benefit_sponsor_employer_profile_id(
                            organization.employer_profile.id
                          ).active

  (2..last_row).each do |row_number|
    row_info         =  sheet_data.row(row_number)
    key              =  row_info[headers["ssn"]].to_s.squish.gsub('-', '')
    first_name       =  row_info[headers["first_name"]].squish if headers["first_name"]
    last_name        =  row_info[headers["last_name"]].squish  if headers["last_name"]
    first_initial    =  first_name[0]
    hidden_ssn       =  key.to_s.gsub(/(\d{3})(\d{2})(\d{4})/, '\1-\2-\3').gsub(/\d{3}-\d{2}/, 'xxx-xx')
    termination_date =  row_info[headers["termdate"]].to_s.squish
    term_date        =  Date.parse(termination_date)
    census_employees =  all_census_employees.by_ssn(key)

    if census_employees.size > 1
      puts "Staffer #{first_initial} #{last_name.capitalize} (#{hidden_ssn}) has multiple (#{census_employees.size}) census employee records.".red
    else
      census_employee = census_employees.first
      if census_employee.present?
        if dry_run
          if census_employee.may_terminate_employee_role?
            puts "[DRY RUN] Eligible to terminate #{first_initial}. #{last_name.capitalize} on #{term_date} (would terminate)."
          else
            puts "[DRY RUN] #{first_initial}. #{last_name.capitalize} is NOT eligible for termination right now."
          end
        else
          if census_employee.may_terminate_employee_role?
            puts "Terminating census employee #{first_initial}. #{last_name.capitalize} with termination date of #{term_date}"
            census_employee.terminate_employment(term_date)
            puts "Successfully terminated census employee #{first_initial}. #{last_name.capitalize} with a termination date of #{census_employee.employment_terminated_on}"
          else
            puts "Unable to terminate #{first_initial}. #{last_name.capitalize} — not in a terminatable state."
          end
        end
      else
        puts "Unable to find census employee with SSN #{hidden_ssn}."
      end
    end
  end
end





house_bulk_term(file_date: '8/2025', dry_run: true)   # simulate only
house_bulk_term(file_date: '8/2025', dry_run: false)  # actually terminate