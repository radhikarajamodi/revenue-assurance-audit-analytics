#!/usr/bin/env ruby
# Optional macOS fallback: execute the SAME SQL when Python is unavailable.
# Standard-library Ruby and the bundled sqlite3/zip CLIs only. No monetary floats.
require 'csv'
require 'json'
require 'open3'
require 'digest'
require 'fileutils'
require 'tmpdir'
require 'cgi'
require 'set'
ROOT = File.expand_path('..', __dir__)
DB = File.join(ROOT, 'data/revenue_audit.sqlite')
OUT = File.join(ROOT, 'reports')
ASOF = '2025-12-31'

def query(statement, db=DB)
  stdout, stderr, status = Open3.capture3('/usr/bin/sqlite3', '-bail', '-json', db, stdin_data: statement)
  raise stderr unless status.success?
  stdout.strip.empty? ? [] : JSON.parse(stdout)
end

def named(name, as_of=ASOF, branch=0)
  raise 'Invalid scope' unless as_of.match?(/\A\d{4}-\d{2}-\d{2}\z/) && (0..4).include?(branch)
  query(File.read(File.join(ROOT,'sql',name+'.sql')).gsub(':as_of', "'#{as_of}'").gsub(':branch', branch.to_s))
end

def dollars(n)
  sign = n < 0 ? '-' : ''
  n = n.abs
  "#{sign}$#{(n/100).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}.#{(n%100).to_s.rjust(2,'0')}"
end

def workbook(path, tables)
  # Valid OOXML workbook. Python's normal export path uses pandas/openpyxl.
  Dir.mktmpdir('xlsx-', File.join(ROOT,'data')) do |temp|
    FileUtils.mkdir_p(File.join(temp,'_rels'))
    FileUtils.mkdir_p(File.join(temp,'xl/_rels'))
    FileUtils.mkdir_p(File.join(temp,'xl/worksheets'))
    sheets=[]; relations=[]; overrides=[]
    tables.each_with_index do |(name, rows), idx|
      num=idx+1
      sheets << %Q(<sheet name="#{CGI.escapeHTML(name[0,31])}" sheetId="#{num}" r:id="rId#{num}"/>)
      relations << %Q(<Relationship Id="rId#{num}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet#{num}.xml"/>)
      overrides << %Q(<Override PartName="/xl/worksheets/sheet#{num}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>)
      headers = rows.empty? ? ['No rows in scope'] : rows.first.keys
      data = [headers] + rows.map{|r| headers.map{|h|r[h]}}
      xml=data.each_with_index.map do |row, ridx|
        cells=row.each_with_index.map do |value,cidx|
          col=''; x=cidx+1
          while x>0; x,mod=(x-1).divmod(26); col=(65+mod).chr+col; end
          ref="#{col}#{ridx+1}"
          value.is_a?(Integer) ? %Q(<c r="#{ref}"><v>#{value}</v></c>) : %Q(<c r="#{ref}" t="inlineStr"><is><t xml:space="preserve">#{CGI.escapeHTML(value.to_s)}</t></is></c>)
        end.join
        %Q(<row r="#{ridx+1}">#{cells}</row>)
      end.join
      File.write(File.join(temp,"xl/worksheets/sheet#{num}.xml"), %Q(<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetData>#{xml}</sheetData></worksheet>))
    end
    File.write(File.join(temp,'[Content_Types].xml'), %Q(<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>#{overrides.join}</Types>))
    File.write(File.join(temp,'_rels/.rels'), %Q(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>))
    File.write(File.join(temp,'xl/workbook.xml'), %Q(<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>#{sheets.join}</sheets></workbook>))
    File.write(File.join(temp,'xl/_rels/workbook.xml.rels'), %Q(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">#{relations.join}</Relationships>))
    File.delete(path) if File.exist?(path)
    _, error, status=Open3.capture3('/usr/bin/zip','-q','-r',path,'.',chdir:temp)
    raise error unless status.success?
  end
end

checks=[]
check=lambda do |name, condition|
  checks << {'check'=>name,'status'=>condition ? 'PASS' : 'FAIL'}
  raise "Failed: #{name}" unless condition
end
check.call('SQLite database integrity', query('PRAGMA integrity_check').first.values.first=='ok')
check.call('Foreign key integrity', query('PRAGMA foreign_key_check').empty?)
check.call('Actual invoice count', query('SELECT count(*) n FROM invoices').first['n']==12024)
check.call('All journals balanced', query('SELECT journal_id FROM journal_lines GROUP BY journal_id HAVING sum(debit_cents)<>sum(credit_cents)').empty?)
check.call('Money stored as integer cents', query("SELECT invoice_id FROM invoices WHERE typeof(amount_cents)<>'integer'").empty?)
check.call('Cash GL equals receipts', query("SELECT (SELECT sum(debit_cents-credit_cents) FROM journal_lines WHERE account_id='1000')=(SELECT sum(amount_cents) FROM payments) ok").first['ok']==1)
check.call('Returns debit net revenue', query("SELECT (SELECT sum(debit_cents-credit_cents) FROM journal_lines WHERE account_id='4090')=(SELECT sum(amount_cents) FROM credit_memos) ok").first['ok']==1)
check.call('No pre-fiscal recognition / zero initial AR', query("SELECT invoice_id FROM invoices WHERE recognition_date<'2025-01-01'").empty?)
check.call('Clean split shipment not flagged', query('SELECT * FROM v_exceptions WHERE invoice_id=101').empty?)
check.call('Clean line-level fulfillment', query('SELECT * FROM v_line_issues').empty?)
check.call('Late approval rejected; timely independent approval accepted', query('SELECT journal_id,valid_approval FROM v_manual_evidence WHERE journal_id IN (300003,300004)').map{|r|r['valid_approval']}==[0,1])
check.call('Excess credit retained as credit balance', named('aging').find{|r|r['invoice_id']==107}['balance_cents']==-5000)
check.call('Fully credited invoice has no cash allocation', named('aging').find{|r|r['invoice_id']==103}['balance_cents']==0 && query('SELECT * FROM allocations WHERE invoice_id=103').empty?)
check.call('Unapplied advance classified as deposit', query("SELECT credit_cents FROM journal_lines WHERE journal_id=150001 AND account_id='2100'").first['credit_cents']==150000)
partial=query('SELECT * FROM allocations WHERE invoice_id=119 ORDER BY allocation_date')
amount=query('SELECT amount_cents FROM invoices WHERE invoice_id=119').first['amount_cents']
check.call('Partial cash preserves unpaid balance', partial.length==2 && named('aging',partial[0]['allocation_date']).find{|r|r['invoice_id']==119}['balance_cents']==amount-partial[0]['amount_cents'])
check.call('Second cash clears partial balance', named('aging',partial[1]['allocation_date']).find{|r|r['invoice_id']==119}['balance_cents']==0)
['2025-01-01','2025-03-31','2025-12-31','2026-03-31'].each do |asof|
 (0..4).each do |branch|
  rec=named('reconciliation',asof,branch).first
  check.call("Rollforward #{asof} branch #{branch}",rec['beginning_ar_cents']+rec['credit_sales_cents']-rec['collections_cents']-rec['credits_cents']==rec['ending_ar_cents'])
  check.call("Aging agrees #{asof} branch #{branch}", named('aging',asof,branch).sum{|r|r['balance_cents']}==rec['ending_ar_cents'])
  check.call("Bridge explained #{asof} branch #{branch}", named('bridge',asof,branch).sum{|r|r['bridge_cents']}==rec['difference_cents'])
 end
end
actual=query('SELECT rule_id,risk_key FROM v_exceptions').map{|r|[r['rule_id'],r['risk_key']]}.to_set
expected=query('SELECT rule_id,risk_key FROM labels',File.join(ROOT,'data/ground_truth/labels.sqlite')).map{|r|[r['rule_id'],r['risk_key']]}.to_set
check.call('All planted seeds detected; no unexpected fixture flags',actual==expected)
check.call('Detector DB contains no planted labels',query("SELECT name FROM sqlite_master WHERE name LIKE '%truth%' OR name LIKE '%label%'").empty?)
check.call('One-cent mutation detected without answer key',query("BEGIN; UPDATE invoices SET amount_cents=amount_cents+1 WHERE invoice_id=101; SELECT count(*) n FROM v_exceptions WHERE invoice_id=101 AND rule_id='AMOUNT_MISMATCH'; ROLLBACK;").first['n']==1)
# Prove enforcement is active, including under attempted corruptions; child connection rolls back.
_,_,fk_status=Open3.capture3('/usr/bin/sqlite3','-bail',DB,"PRAGMA foreign_keys=ON; BEGIN; UPDATE invoices SET order_id=9999999 WHERE invoice_id=1; ROLLBACK;")
check.call('Orphan mutation rejected by FK constraint',!fk_status.success?)
_,_,money_status=Open3.capture3('/usr/bin/sqlite3','-bail',DB,"BEGIN; UPDATE invoices SET amount_cents=1.5 WHERE invoice_id=1; ROLLBACK;")
check.call('Fractional-cent mutation rejected',!money_status.success?)

matrix=CSV.read(File.join(ROOT,'docs/risk_control_matrix.csv'),headers:true).map(&:to_h)
registry=matrix.to_h{|r|[r['rule_id'],r]}
exceptions=query("SELECT * FROM v_exceptions WHERE event_date<='#{ASOF}'").map{|r|r.merge(registry.fetch(r['rule_id']))}
counts=exceptions.group_by{|r|r['rule_id']}.transform_values(&:length)
customers=named('customer_risk')
sales=customers.sum{|r|r['sales_cents']}
controls=matrix.map do |r|
 rule=r['rule_id']; n=counts.fetch(rule,0)
 n=customers.count{|c|c['late_settled_invoices']>=3} if rule=='LATE_PAYMENTS'
 n=customers.count{|c|sales>0 && c['sales_cents']*100>=sales*10} if rule=='CONCENTRATION'
 pop=if ['MANUAL_UNAUTHORIZED','APPROVAL_FAILURE'].include?(rule); query('SELECT count(*) n FROM journal_entries WHERE manual=1').first['n']
 elsif rule.start_with?('CASH_'); query('SELECT count(*) n FROM allocations').first['n']
 elsif rule=='CREDIT_EXCESS'; query('SELECT count(DISTINCT invoice_id) n FROM credit_memos').first['n']
 elsif ['LATE_PAYMENTS','CONCENTRATION'].include?(rule); customers.length
 else; query('SELECT count(*) n FROM invoices').first['n']; end
 r.merge('exception_count'=>n,'full_extract_population'=>pop,'result'=>n>0 ? 'Investigate exceptions' : 'No exception detected','scope_note'=>'Exception counts follow snapshot; population is full extract. No failure-rate inference.')
end
tables={}
%w[reconciliation bridge aging customer_risk kpis revenue_reconciliation data_quality].each{|name|tables[name]=named(name)}
tables['exceptions']=exceptions
tables['controls']=controls
tables['scope']=[{'as_of'=>ASOF,'branch'=>0,'classification'=>'SYNTHETIC','exception_basis'=>'Retrospective full-extract evidence','currency'=>'USD integer cents','actual_loss'=>'Not assessed'}]
FileUtils.mkdir_p(OUT)
tables.each do |name,rows|
 CSV.open(File.join(OUT,name+'.csv'),'w') do |csv|
  headers=rows.first.keys; csv << headers
  rows.each{|r|csv << headers.map{|h|r[h]}}
 end
end
workbook(File.join(OUT,'audit_workpapers.xlsx'),tables)
workbook(File.join(OUT,'risk_control_matrix.xlsx'),{'Risk and controls'=>controls})
items=exceptions.group_by{|r|r['risk_key']}
exposure={'unique_items'=>items.length}
{'flagged_value_cents'=>'flagged_value_cents','estimated_exposure_cents'=>'exposure_cents','quantified_difference_cents'=>'discrepancy_cents'}.each{|out,col|exposure[out]=items.values.sum{|rows|rows.map{|r|r[col]}.max}}
rec=tables['reconciliation'].first
summary={'classification'=>'SYNTHETIC','as_of'=>ASOF,'invoice_count'=>query('SELECT count(*) n FROM invoices').first['n'],'exceptions_by_type'=>counts.sort.to_h,'exposure'=>exposure,'reconciliation'=>rec,'actual_loss'=>'Not assessed','database_sha256'=>Digest::SHA256.file(DB).hexdigest,'export_engine'=>'SQLite CLI + Ruby standard library (Python unavailable on authoring host)'}
File.write(File.join(OUT,'summary.json'),JSON.pretty_generate(summary)+"\n")
File.write(File.join(OUT,'sql_validation.json'),JSON.pretty_generate({'engine'=>query('SELECT sqlite_version() version').first['version'],'passed'=>checks.length,'failed'=>0,'checks'=>checks,'python_pytest'=>'NOT RUN: no working Python runtime','streamlit_smoke'=>'NOT RUN: no working Python runtime'})+"\n")
rows=counts.sort.map{|k,v|"| #{k} | #{v} |"}.join("\n")
File.write(File.join(OUT,'executive_findings.md'),<<~MD)
# Executive findings — SYNTHETIC

Fictional Northstar Parts, fiscal 2025; as of #{ASOF}. #{summary['invoice_count']} invoices. These are analytical exceptions, not proven fraud, GAAP violations, or real audit findings.

| Test | Exceptions |
|---|---:|
#{rows}

AR subledger: **#{dollars(rec['ending_ar_cents'])}**. GL AR: **#{dollars(rec['gl_ar_cents'])}**. GL less subledger: **#{dollars(rec['difference_cents'])}**. The independent bridge explains the entire difference, including zero categories; this does not validate the original postings.

Unique flagged transaction value: **#{dollars(exposure['flagged_value_cents'])}** across #{exposure['unique_items']} economic items. Conservative potential exposure envelope: **#{dollars(exposure['estimated_exposure_cents'])}**. Quantified arithmetic extract differences: **#{dollars(exposure['quantified_difference_cents'])}**; these are not confirmed misstatements. Actual loss: **not assessed**. Never add exposure subtotals across rules; the same invoice/journal can trigger multiple procedures.

Immediate priority: remove unauthorized manual journal access and enforce independent pre-posting approval (IT access owner and controller). Within 30 days: block duplicate billing, link invoices to shipments, enforce cash allocation controls and reconcile interfaces daily (billing and AR managers). Within 60 days: review repeat late payers and customer dependency (credit manager). These are proposed remediations, not implemented business benefits.

Auditor follow-up: validate extract completeness to independent control totals; inspect contracts and carrier evidence; confirm customer balances and inspect bank remittances; evaluate approvals and compensating controls; obtain supported correcting entries and retest.

Verification: #{checks.length} SQL/SQLite validation checks passed on the authoring host. Python pytest and Streamlit were not run because no working Python runtime was available. XLSX artifacts were produced by the documented Ruby fallback using executed SQL results. The normal Python export uses pandas/openpyxl and requires runtime validation.
MD
manifest=Dir.glob(File.join(OUT,'*')).select{|p|File.file?(p) && File.basename(p)!='manifest.json'}.sort.to_h{|p|[File.basename(p),Digest::SHA256.file(p).hexdigest]}
File.write(File.join(OUT,'manifest.json'),JSON.pretty_generate(manifest)+"\n")
puts JSON.pretty_generate(summary)
puts "SQL checks: #{checks.length} passed; 0 failed. Python/Streamlit: not run."
