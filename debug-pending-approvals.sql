-- Debug Pending Approvals Issue
-- Run this script in your Supabase SQL Editor

-- 1. Check all employees
SELECT '=== ALL EMPLOYEES ===' as info;
SELECT id, name, email FROM employees ORDER BY name;

-- 2. Check all requests with exchange partners
SELECT '=== ALL EXCHANGE REQUESTS ===' as info;
SELECT 
    r.id,
    r.employee_name,
    r.employee_email,
    r.type,
    r.exchange_partner_id,
    r.exchange_partner_approved,
    r.exchange_partner_approved_at,
    r.status,
    r.created_at,
    e.name as partner_name,
    e.email as partner_email
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.exchange_partner_id IS NOT NULL
ORDER BY r.created_at DESC;

-- 3. Check all notifications
SELECT '=== ALL NOTIFICATIONS ===' as info;
SELECT 
    n.id,
    n.employee_id,
    n.request_id,
    n.type,
    n.title,
    n.is_read,
    n.created_at,
    e.name as employee_name,
    e.email as employee_email
FROM notifications n
JOIN employees e ON n.employee_id = e.id
ORDER BY n.created_at DESC;

-- 4. Test the get_pending_exchange_approvals function for each employee
SELECT '=== TESTING PENDING APPROVALS FUNCTION ===' as info;

-- Get all employees and test the function for each
DO $$
DECLARE
    emp_record RECORD;
    approval_record RECORD;
    approval_count INTEGER;
BEGIN
    FOR emp_record IN SELECT id, name, email FROM employees ORDER BY name
    LOOP
        RAISE NOTICE 'Testing pending approvals for employee: % (ID: %)', emp_record.name, emp_record.id;
        
        approval_count := 0;
        FOR approval_record IN 
            SELECT * FROM get_pending_exchange_approvals(emp_record.id)
        LOOP
            approval_count := approval_count + 1;
            RAISE NOTICE '  - Request ID: %, Requester: %, From: %, To: %', 
                approval_record.request_id, 
                approval_record.requester_name,
                approval_record.exchange_from_date,
                approval_record.exchange_to_date;
        END LOOP;
        
        RAISE NOTICE '  Total pending approvals: %', approval_count;
    END LOOP;
END $$;

-- 5. Manual query to check what should be returned
SELECT '=== MANUAL PENDING APPROVALS CHECK ===' as info;
SELECT 
    e.name as employee_name,
    e.email as employee_email,
    r.id as request_id,
    r.employee_name as requester_name,
    r.employee_email as requester_email,
    r.exchange_from_date,
    r.exchange_to_date,
    r.exchange_reason,
    r.exchange_partner_approved,
    r.status,
    r.created_at
FROM employees e
LEFT JOIN requests r ON e.id = r.exchange_partner_id 
    AND r.exchange_partner_approved = FALSE 
    AND r.status = 'Pending'
ORDER BY e.name, r.created_at DESC;

-- 6. Check if there are any requests where partner_approved is NULL
SELECT '=== REQUESTS WITH NULL PARTNER APPROVAL ===' as info;
SELECT 
    r.id,
    r.employee_name,
    r.employee_email,
    r.exchange_partner_id,
    r.exchange_partner_approved,
    r.status,
    e.name as partner_name
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.exchange_partner_id IS NOT NULL
AND r.exchange_partner_approved IS NULL;

-- 7. Fix any NULL values in exchange_partner_approved
UPDATE requests 
SET exchange_partner_approved = FALSE
WHERE exchange_partner_id IS NOT NULL 
AND exchange_partner_approved IS NULL;

-- 8. Re-create the get_pending_exchange_approvals function with better debugging
CREATE OR REPLACE FUNCTION get_pending_exchange_approvals(p_employee_id BIGINT)
RETURNS TABLE(
    request_id BIGINT,
    requester_name VARCHAR(255),
    requester_email VARCHAR(255),
    exchange_from_date DATE,
    exchange_to_date DATE,
    exchange_reason TEXT,
    request_created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RAISE NOTICE 'get_pending_exchange_approvals called for employee ID: %', p_employee_id;
    
    RETURN QUERY
    SELECT 
        r.id,
        r.employee_name,
        r.employee_email,
        r.exchange_from_date,
        r.exchange_to_date,
        r.exchange_reason,
        r.created_at
    FROM requests r
    WHERE r.exchange_partner_id = p_employee_id
    AND r.exchange_partner_approved = FALSE
    AND r.status = 'Pending'
    ORDER BY r.created_at DESC;
    
    RAISE NOTICE 'Function completed for employee ID: %', p_employee_id;
END;
$$ LANGUAGE plpgsql;

-- 9. Test the function again after fixes
SELECT '=== TESTING FIXED FUNCTION ===' as info;

-- Test for specific employees (adjust names as needed)
SELECT 'Testing for Mohamed' as test_case, * FROM get_pending_exchange_approvals(
    (SELECT id FROM employees WHERE name ILIKE '%mohamed%' LIMIT 1)
);

SELECT 'Testing for Engy' as test_case, * FROM get_pending_exchange_approvals(
    (SELECT id FROM employees WHERE name ILIKE '%engy%' LIMIT 1)
);

-- 10. Final status check
SELECT '=== FINAL STATUS ===' as info;

-- Show summary by employee
SELECT 
    e.name as employee_name,
    e.email as employee_email,
    COUNT(r.id) as total_exchange_requests,
    COUNT(CASE WHEN r.exchange_partner_approved = FALSE AND r.status = 'Pending' THEN 1 END) as pending_approvals,
    COUNT(n.id) as total_notifications,
    COUNT(CASE WHEN n.is_read = FALSE THEN 1 END) as unread_notifications
FROM employees e
LEFT JOIN requests r ON e.id = r.exchange_partner_id
LEFT JOIN notifications n ON e.id = n.employee_id
GROUP BY e.id, e.name, e.email
ORDER BY pending_approvals DESC, e.name; 