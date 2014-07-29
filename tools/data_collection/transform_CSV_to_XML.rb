#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'builder'
require 'csv'
require 'net/http'
require 'nokogiri'
require 'optparse'
require 'ostruct'
require 'pp'
require 'tempfile'
require 'time'
require_relative './lib/CX.rb'

csv_filename = nil
options = OpenStruct.new
options.email_recipients = "lspeelmon@rsmart.com"
@col_sep = ','
options.xml_filename = "hrimport.xml"
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options] csv_file"

  opts.on('--email [email_recipients]', 'Email recipient list that will receive job report...') do |e|
    options.email_recipients = e
  end

  opts.on('--output [xml_file_output]', 'The file the XML data will be writen to... (defaults to hrimport.xml)') do |f|
    options.xml_filename = f
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end

  csv_filename = ARGV[0]
  if csv_filename.nil? || csv_filename.empty?
    puts opts
    exit
  end
end
optparse.parse!

csv_options = { headers: :first_row,
                header_converters: :symbol,
                skip_blanks: true,
                col_sep: @col_sep,
                }

CSV.open(csv_filename, csv_options) do |csv|
  record_count = csv.readlines.count
  csv.rewind # go back to first row

  File.open(options.xml_filename, 'w') do |xml_file|
    xml = Builder::XmlMarkup.new target: xml_file, indent: 2
    xml.instruct! :xml, encoding: "UTF-8"
    xml.hrmanifest "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
      "xsi:schemaLocation" => "https://github.com/rSmart/ce-tech-docs/tree/master/v1_0 https://raw.github.com/rSmart/ce-tech-docs/master/v1_0/hrmanifest.xsd",
      xmlns: "https://github.com/rSmart/ce-tech-docs/tree/master/v1_0",
      schemaVersion: "1.0",
      statusEmailRecipient: options.email_recipients,
      reportDate: Time.now.iso8601,
    recordCount: record_count do |hrmanifest|
      hrmanifest.records do |record|
        csv.find_all do |row| # begin processing csv rows
          begin
            xml.record principalId: CX.parse_principal_id( row[:prncpl_id] ),
            principalName: CX.parse_principal_name( row[:prncpl_nm] ) do |record|
              record.affiliations do |affiliations|
                aff = {}
                afltn_typ_cd = CX.parse_string row[:afltn_typ_cd], length: 40, strict: true
                campus       = CX.parse_string row[:campus_cd], length: 2, strict: true
                aff[:affiliationType] = afltn_typ_cd unless afltn_typ_cd.empty?
                aff[:campus]          = campus unless campus.empty?
                aff[:default]         = true
                aff[:active]          = true

                affiliations.affiliation aff do |affiliation|
                  emp = {}
                  emp_stat_cd   = CX.parse_emp_stat_cd row[:emp_stat_cd]
                  emp_typ_cd    = CX.parse_emp_typ_cd  row[:emp_typ_cd]
                  base_slry_amt = CX.parse_float       row[:base_slry_amt], length: 15, strict: true
                  prmry_dept_cd = CX.parse_string      row[:prmry_dept_cd], length: 40, strict: true
                  emp_id        = CX.parse_string      row[:emp_id],        length: 40, strict: true
                  emp[:employeeStatus]    = emp_stat_cd unless emp_stat_cd.empty?
                  emp[:employeeType]      = emp_typ_cd unless emp_typ_cd.empty?
                  emp[:baseSalaryAmount]  = base_slry_amt unless base_slry_amt.nil?
                  emp[:primaryDepartment] = prmry_dept_cd unless prmry_dept_cd.empty?
                  emp[:employeeId]        = emp_id unless emp_id.empty?
                  emp[:primaryEmployment] = true

                  affiliation.employment emp
                end
              end # affiliations
              record.names do |names|
                nm = {}
                nm_typ_cd = CX.parse_name_code row[:nm_typ_cd]
                prefix_nm = CX.parse_prefix    row[:prefix_nm]
                first_nm  = CX.parse_string    row[:first_nm],  length: 40, strict: true
                middle_nm = CX.parse_string    row[:middle_nm], length: 40, strict: true
                last_nm   = CX.parse_string    row[:last_nm],   length: 80, strict: true
                suffix_nm = CX.parse_suffix    row[:suffix_nm]
                title_nm  = CX.parse_string    row[:title_nm],  length: 20, strict: true
                nm[:nameCode]   = nm_typ_cd unless nm_typ_cd.empty?
                nm[:prefix]     = prefix_nm unless prefix_nm.empty?
                nm[:firstName]  = first_nm unless first_nm.empty?
                nm[:middleName] = middle_nm unless middle_nm.empty?
                nm[:lastName]   = last_nm unless last_nm.empty?
                nm[:suffix]     = suffix_nm unless suffix_nm.empty?
                nm[:title]      = title_nm unless title_nm.empty?
                nm[:default]    = true
                nm[:active]     = true

                names.name nm
              end # names

              ph = {}
              phone_typ_cd    = CX.parse_phone_type   row[:phone_typ_cd]
              phone_nbr       = CX.parse_phone_number row[:phone_nbr]
              phone_extn_nbr  = CX.parse_string       row[:phone_extn_nbr],  length: 8, strict: true
              postal_cntry_cd = CX.parse_string       row[:postal_cntry_cd], length: 2, strict: true
              ph[:phoneType]   = phone_typ_cd unless phone_typ_cd.empty?
              ph[:phoneNumber] = phone_nbr unless phone_nbr.empty?
              ph[:extension]   = phone_extn_nbr unless phone_extn_nbr.empty?
              ph[:country]     = postal_cntry_cd unless postal_cntry_cd.empty?
              ph[:default]     = true
              ph[:active]      = true

              unless phone_typ_cd.empty? || phone_nbr.empty?
                record.phones do |phones|
                  phones.phone ph
                end # phones
              end

              em = {}
              email_typ_cd = CX.parse_email_type( row[:email_typ_cd] )
              email_addr = CX.parse_email_address( row[:email_addr] )
              em[:emailType] = email_typ_cd unless email_typ_cd.empty?
              em[:emailAddress] = email_addr unless email_addr.empty?
              em[:default] = true
              em[:active]  = true

              unless email_typ_cd.empty? || email_addr.empty?
                record.emails do |emails|
                  emails.email em unless email_addr.empty?
                end # emails
              end

              ea = {}
              visa_type = CX.parse_string( row[:visa_type], length: 30, strict: true )
              county = CX.parse_string(  row[:county], length: 30, strict: true )
              age_by_fiscal_year = CX.parse_integer( row[:age_by_fiscal_year], length: 3 )
              race = CX.parse_string(  row[:race], length: 30, strict: true )
              education_level = CX.parse_string(  row[:education_level], length: 30, strict: true )
              degree = CX.parse_degree(  row[:degree] )
              major = CX.parse_string(  row[:major], length: 30, strict: true )
              is_handicapped = CX.parse_boolean row[:is_handicapped]
              handicap_type = CX.parse_string(  row[:handicap_type], length: 30, strict: true )
              is_veteran = CX.parse_boolean( row[:is_veteran] )
              veteran_type = CX.parse_string(  row[:veteran_type], length: 30, strict: true )
              has_visa = CX.parse_boolean( row[:has_visa] )
              visa_code = CX.parse_string(  row[:visa_code], length: 20, strict: true )
              visa_renewal_date = CX.parse_string(  row[:visa_renewal_date], length: 19 )
              office_location = CX.parse_string(  row[:office_location], length: 30, strict: true )
              secondry_office_location = CX.parse_string(  row[:secondry_office_location], length: 30, strict: true )
              school = CX.parse_string(  row[:school], length: 50, strict: true )
              year_graduated = CX.parse_year(    row[:year_graduated] )
              directory_department = CX.parse_string(  row[:directory_department], length: 30, strict: true )
              directory_title = CX.parse_string(  row[:directory_title], length: 50, strict: true )
              primary_title = CX.parse_string(  row[:primary_title], length: 51, strict: true )
              vacation_accural = CX.parse_boolean( row[:vacation_accural] )
              is_on_sabbatical = CX.parse_boolean( row[:is_on_sabbatical] )
              id_provided = CX.parse_string(  row[:id_provided], length: 30, strict: true )
              id_verified = CX.parse_string(  row[:id_verified], length: 30, strict: true )
              citizenship_type_code = CX.parse_citizenship_type( row[:citizenship_type_code] )
              multi_campus_principal_id = CX.parse_string(  row[:multi_campus_principal_id], length: 40, strict: true )
              multi_campus_principal_name = CX.parse_string(  row[:multi_campus_principal_name], length: 100, strict: true )
              salary_anniversary_date = CX.parse_string(  row[:salary_anniversary_date], length: 10 )
              ea[:visaType] = visa_type unless visa_type.empty?
              ea[:county] = county unless county.empty?
              ea[:ageByFiscalYear] = age_by_fiscal_year unless age_by_fiscal_year.nil?
              ea[:race] = race unless race.empty?
              ea[:educationLevel] = education_level unless education_level.empty?
              ea[:degree] = degree unless degree.empty?
              ea[:major] = major unless major.empty?
              ea[:handicapped] = is_handicapped unless is_handicapped.nil?
              ea[:handicapType] = handicap_type unless handicap_type.empty?
              ea[:veteran] = is_veteran unless is_veteran.nil?
              ea[:veteranType] = veteran_type unless veteran_type.empty?
              ea[:visa] = has_visa unless has_visa.nil?
              ea[:visaCode] = visa_code unless visa_code.empty?
              ea[:visaRenewalDate] = visa_renewal_date unless visa_renewal_date.empty?
              ea[:officeLocation] = office_location unless office_location.empty?
              ea[:secondaryOfficeLocation] = secondry_office_location unless secondry_office_location.empty?
              ea[:school] = school unless school.empty?
              ea[:yearGraduated] = year_graduated unless year_graduated.empty?
              ea[:directoryDepartment] = directory_department unless directory_department.empty?
              ea[:directoryTitle] = directory_title unless directory_title.empty?
              ea[:primaryTitle] = primary_title unless primary_title.empty?
              ea[:vacationAccrual] = vacation_accural unless vacation_accural.nil?
              ea[:onSabbatical] = is_on_sabbatical unless is_on_sabbatical.nil?
              ea[:idProvided] = id_provided unless id_provided.empty?
              ea[:idVerified] = id_verified unless id_verified.empty?
              ea[:citizenshipType] = citizenship_type_code unless citizenship_type_code.empty?
              ea[:multiCampusPrincipalId] = multi_campus_principal_id unless multi_campus_principal_id.empty?
              ea[:multiCampusPrincipalName] = multi_campus_principal_name unless multi_campus_principal_name.empty?
              ea[:salaryAnniversaryDate] = salary_anniversary_date unless salary_anniversary_date.empty?

              record.kcExtendedAttributes ea

              ap = {}
              unit_number = CX.parse_string( row[:unit_number], length: 8, strict: true )
              appointment_type_code = CX.parse_string( row[:appointment_type_code], length: 3, strict: true )
              job_code = CX.parse_string( row[:job_code], length: 6, strict: true )
              salary = CX.parse_float(  row[:salary], length: 15, strict: true )
              appointment_start_date = CX.parse_string( row[:appointment_start_date] )
              appointment_end_date = CX.parse_string( row[:appointment_end_date] )
              job_title = CX.parse_string( row[:job_title], length: 50, strict: true )
              prefered_job_title = CX.parse_string( row[:prefered_job_title], length: 51, strict: true )
              ap[:unitNumber] = unit_number unless unit_number.empty?
              ap[:appointmentType] = appointment_type_code unless appointment_type_code.empty?
              ap[:jobCode] = job_code unless job_code.empty?
              ap[:salary] = salary unless salary.nil?
              ap[:startDate] = appointment_start_date unless appointment_start_date.empty?
              ap[:endDate] = appointment_end_date unless appointment_end_date.empty?
              ap[:jobTitle] = job_title unless job_title.empty?
              ap[:preferedJobTitle] = prefered_job_title unless prefered_job_title.empty?

              unless unit_number.empty? || job_code.empty?
                record.appointments do |appointments|
                  appointments.appointment ap
                end # appointments
              end
            end # record

          rescue TextParseError => e
            puts e.message
          end
        end # row
      end # record
    end # hrmanifest
  end # file
end # csv

# validate the resulting XML file against the official XSD schema
uri = URI 'https://raw.githubusercontent.com/rSmart/ce-tech-docs/master/hrmanifest.xsd'
Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
  Tempfile.open "hrmanifest.xsd" do |file|
    request = Net::HTTP::Get.new uri
    http.request request do |response|
      response.read_body do |segment|
        file.write(segment)
      end
    end
    file.rewind
    xsd = Nokogiri::XML::Schema file
    doc = Nokogiri::XML File.read options.xml_filename
    xml_errors = xsd.validate doc
    if xml_errors.empty?
      puts "Congratulations! The XML file passes XSD schema validation! w00t!"
    else
      xml_errors.each do |error|
        puts error.message
      end
    end
  end # file
end
