SELECT 'Invoice/order/shipment line issues' check_name,count(*) issue_count,'Full extract' scope FROM v_line_issues
UNION ALL SELECT 'Unsupported or excess return credits',count(*),'Full extract' FROM v_credit_support_issues
UNION ALL SELECT 'Employees with conflicting permissions',count(*),'Full extract' FROM v_permission_conflicts
UNION ALL SELECT 'Log actions without matching permission',count(*),'Full extract' FROM activity_logs l WHERE NOT EXISTS(SELECT 1 FROM employee_roles er JOIN permissions p USING(role_id) WHERE er.employee_id=l.employee_id AND p.action=l.action);
