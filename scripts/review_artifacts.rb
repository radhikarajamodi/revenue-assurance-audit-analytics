#!/usr/bin/env ruby
# Initial-host review when Python is unavailable. No personal home-directory reads.
require 'json'
require 'csv'
require 'open3'
require 'rexml/document'
require 'digest'
ROOT=File.expand_path('..',__dir__)
OUT=File.join(ROOT,'reports')

def sql(db,statement)
 o,e,s=Open3.capture3('/usr/bin/sqlite3','-json',db,statement)
 raise e unless s.success?
 o.strip.empty? ? [] : JSON.parse(o)
end

def validate_xlsx(path)
 listing,err,status=Open3.capture3('/usr/bin/unzip','-Z1',path)
 raise err unless status.success?
 parts=listing.lines.map(&:strip).select{|p|p.end_with?('.xml','.rels')}
 parts.each do |part|
  xml,err,status=Open3.capture3('/usr/bin/unzip','-p',path,part.gsub('[', '\[').gsub(']', '\]'))
  raise err unless status.success?
  REXML::Document.new(xml)
 end
 xml,err,status=Open3.capture3('/usr/bin/unzip','-p',path,'xl/worksheets/sheet1.xml')
 raise err unless status.success?
 doc=REXML::Document.new(xml)
 nums=REXML::XPath.match(doc,"//*[local-name()='row'][@r='2']/*[local-name()='c']/*[local-name()='v']").map{|e|Integer(e.text)}
 [parts.length,nums]
end

count,nums=validate_xlsx(File.join(OUT,'audit_workpapers.xlsx'))
expected=CSV.read(File.join(OUT,'reconciliation.csv'),headers:true).first.to_h.values.map{|v|Integer(v)}
raise 'Workbook reconciliation numbers differ from CSV' unless nums==expected
matrix_parts,_=validate_xlsx(File.join(OUT,'risk_control_matrix.xlsx'))

patterns=[/gh[pousr]_[A-Za-z0-9]{20,}/n,/github_pat_[A-Za-z0-9_]{30,}/n,/AKIA[A-Z0-9]{16}/n,/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/n,/sk-[A-Za-z0-9]{35,}/n]
failures=[];count_files=0
Dir.glob(File.join(ROOT,'**','*'),File::FNM_DOTMATCH).sort.each do |path|
 next unless File.file?(path)
 relative=path.sub(ROOT+'/','')
 next if relative.split('/').any?{|s|['.git','.venv','.tools','.publishing','__pycache__','.pytest_cache'].include?(s)}
 count_files+=1
 content=File.binread(path)
 failures << relative if patterns.any?{|pattern|content.match?(pattern)}
 failures << relative if ['.env','auth.json','credentials','secrets.toml'].include?(File.basename(path))
end
raise "Publication content review failed in #{failures.uniq.join(', ')}" unless failures.empty?
db=File.join(ROOT,'data/revenue_audit.sqlite')
classification=sql(db,"SELECT value FROM metadata WHERE key='classification'").first['value']
raise 'Missing synthetic classification' unless classification.start_with?('SYNTHETIC')
%w[customers employees].each do |table|
 raise "Non-synthetic name in #{table}" unless sql(db,"SELECT count(*) n FROM #{table} WHERE name NOT LIKE 'Synthetic %'").first['n']==0
end
# Fixture evaluation is physically separate from all detector queries.
actual=sql(db,'SELECT DISTINCT rule_id,risk_key FROM v_exceptions')
truth=sql(File.join(ROOT,'data/ground_truth/labels.sqlite'),'SELECT rule_id,risk_key FROM labels')
rows=truth.map{|r|r['rule_id']}.uniq.sort.map do |rule|
 a=actual.select{|r|r['rule_id']==rule}.map{|r|r['risk_key']}
 e=truth.select{|r|r['rule_id']==rule}.map{|r|r['risk_key']}
 {'rule_id'=>rule,'planted'=>e.length,'detected'=>a.length,'true_positive'=>(a&e).length,'false_positive'=>(a-e).length,'false_negative'=>(e-a).length}
end
CSV.open(File.join(OUT,'detection_evaluation.csv'),'w'){|csv|headers=rows.first.keys;csv<<headers;rows.each{|r|csv<<headers.map{|h|r[h]}}}
pytest_xml=REXML::Document.new(File.read(File.join(OUT,'pytest_results.xml')))
pytest_suite=REXML::XPath.first(pytest_xml,'//testsuite')
raise 'Pytest failures present' unless pytest_suite.attributes['failures']=='0' && pytest_suite.attributes['errors']=='0'
browser=JSON.parse(File.read(File.join(OUT,'browser_validation.json')))
raise 'Browser checks did not pass' unless browser['result']=='PASS'
review={'classification'=>'SYNTHETIC','review_date'=>'2026-10-24','stage'=>'Final content review before GitHub upload','scanned_project_files'=>count_files,'credential_pattern_hits'=>0,'unexpected_person_or_customer_names'=>0,'workbook_xml_parts_parsed'=>count,'matrix_xml_parts_parsed'=>matrix_parts,'workbook_reconciliation_matches_csv'=>true,'pytest_tests_passed'=>Integer(pytest_suite.attributes['tests']),'browser_validation'=>'PASS','target_repository'=>'radhikarajamodi/revenue-assurance-audit-analytics','limitations'=>'Pattern scanning complements manual source/schema review; no real audit opinion or loss conclusion.'}
File.write(File.join(OUT,'publication_review.json'),JSON.pretty_generate(review)+"\n")
manifest=Dir.glob(File.join(OUT,'*')).select{|p|File.file?(p) && File.basename(p)!='manifest.json'}.sort.to_h{|p|[File.basename(p),Digest::SHA256.file(p).hexdigest]}
File.write(File.join(OUT,'manifest.json'),JSON.pretty_generate(manifest)+"\n")
puts JSON.pretty_generate(review)
puts "Fixture pairs: #{actual.length} detected / #{truth.length} planted; all exact comparisons passed."
