#! /usr/bin/env ruby

require 'nokogiri'
require 'pg_query'


def message(type, sql, tree, fingerprint, fingerprint_deparse, desql_or_err, file_name)
  line = format("\n-------BEGIN-------\nMethod: %-2s\nSQL: %-2s\nFingerprint: %-2s\nFingerprint Deparse: %-2s\nDeparse SQL: %-2s\nTree: %-2s\n--------END-------\n",
                file_name, sql, fingerprint, fingerprint_deparse, desql_or_err.to_s, tree.to_s)
  File.open('results/deparse_' + type + '.result', 'a') do |file|
    file.write(line)
  end

end

file_list = ['ok', 'parser_error', 'deparser_error', 'diff_fingerprint', '']

file_list.each do |delete_filename|
  delete_filename = format('results/deparse_%0s.result', delete_filename)
  File.delete(delete_filename) if File.exist?(delete_filename)
end

line = format("%-2s\t%-30s\t%12s\t%12s\t%18s\t%12s\t%5s\n",
              'OK', 'Method', 'Test Count', 'Pass Count',
              'Fingerprint Err', 'Parser Err', 'Deparser Err')
File.open('results/deparse_.result', 'a') {|file| file.write(line)}


sgml_dir = 'postgres/doc/src/sgml/ref/'

Dir[sgml_dir + '*'].each do |file_name|
  next if File.directory? file_name

  f = File.open(file_name, 'r')
  sql_sub = (file_name.split('/')[5]).split('.')[0].strip
  next if sql_sub == 'allfiles'

  doc = Nokogiri.XML(f, nil, 'UTF-8')
  count = 0
  count_fingerprint = 0
  count_error_deparser = 0
  count_error_parser = 0
  count_ok = 0
  parser = 0
  next if doc.search('refmiscinfo')[0].content.strip == 'Application'

  doc.search('programlisting').each do |link|
    sql = link.content.strip
    begin

      # PgQuery.parse(parsed_sql.deparse).fingerprint
      parser = 1
      parsed_sql = PgQuery.parse(sql)
      parsed_sql.tree
      parser = 0
      parsed_sql.deparse

      if parsed_sql.fingerprint.eql? PgQuery.parse(parsed_sql.deparse).fingerprint
        message('ok',
                sql,
                (parsed_sql.tree unless parsed_sql.nil?),
                (parsed_sql.fingerprint unless parsed_sql.nil?),
                (PgQuery.parse(parsed_sql.deparse).fingerprint unless parsed_sql.deparse.nil?),
                (parsed_sql.deparse unless parsed_sql.deparse.nil?),
                sql_sub)
        count_ok += 1
      else
        message('diff_fingerprint',
                sql,
                (parsed_sql.tree unless parsed_sql.nil?),
                (parsed_sql.fingerprint unless parsed_sql.nil?),
                (PgQuery.parse(parsed_sql.deparse).fingerprint unless parsed_sql.deparse.nil?),
                (parsed_sql.deparse unless parsed_sql.deparse.nil?),
                sql_sub)
        count_fingerprint += 1
      end
    rescue StandardError => e
      if parser == 1
        if e.message.include?('".."') || sql.include?('----')

          print sql + "\n"
          puts e.message.include?('".."')
          puts sql.include?('----')
          puts "\n"
          next
        end
        count_error_parser += 1
        file_name_error = 'parser_error'
      else
        count_error_deparser += 1
        file_name_error = 'deparser_error'
      end
      message(file_name_error,
              sql,
              (parsed_sql.tree unless parsed_sql.nil?),
              (parsed_sql.fingerprint unless parsed_sql.nil?),
              nil,
              e,
              sql_sub)
    end
    count += 1
  end
  line = format("%-2s\t%-30s\t%12i\t%12i\t%18i\t%12i\t%5i\n",
                ('✓' if count == count_ok), sql_sub, count, count_ok,
                count_fingerprint, count_error_parser, count_error_deparser)
  File.open('results/deparse_.result', 'a') {|file| file.write(line)}

end


# print doc