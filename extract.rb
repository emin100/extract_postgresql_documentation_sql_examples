#! /usr/bin/env ruby

require 'nokogiri'
require 'pg_query'


def message(sql, tree, fingerprint, fingerprint_deparse, deparse)
  puts "\n\n\n\n-------" + sql + "-------\n"
  puts tree
  puts "\n"
  puts fingerprint
  puts "\n"
  puts fingerprint_deparse
  puts "\n"
  puts deparse
  puts "\n------- End " + sql + "-------\n"
end


sgml_dir = 'postgres/doc/src/sgml/ref/'


Dir[sgml_dir + '*'].each do |file_name|
  next if File.directory? file_name
  f = File.open(file_name, "r")


  doc = Nokogiri.XML(f, nil, 'UTF-8')

  doc.search('programlisting').each do |link|
    sql = link.content.strip
    error = false
    begin
      parsed_sql = PgQuery.parse(sql)
      # PgQuery.parse(parsed_sql.deparse).fingerprint
      parsed_sql.tree
      parsed_sql.deparse

      unless parsed_sql.fingerprint.eql? PgQuery.parse(parsed_sql.deparse).fingerprint
        message(sql, (parsed_sql.tree unless parsed_sql.nil?), (parsed_sql.fingerprint unless parsed_sql.nil?),
                PgQuery.parse(parsed_sql.deparse).fingerprint, parsed_sql.deparse)
      end
    rescue StandardError => e
      # message(sql, (parsed_sql.tree unless parsed_sql.nil?), (parsed_sql.fingerprint unless parsed_sql.nil?) , nil, e)
    end
  end
end


# print doc