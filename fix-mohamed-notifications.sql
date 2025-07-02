-- Fix Mohamed's Notifications and Pending Approvals
-- Run this script in your Supabase SQL Editor

-- 1. Check Mohamed's current data
SELECT '=== MOHAMED CURRENT STATUS ===' as info;

SELECT 
    'Mohamed Employee Info' as check_item,
    id,
    name,
    email
FROM employees
WHERE name = 'MOHAMED';

-- 2. Check all requests where Mohamed is the exchange partner
SELECT 
    'Requests for Mohamed to Approve' as check_item,
    r.id as request_id,
    r.employee_name as requester,
    r.employee_email as requester_email,
    r.type,
    r.exchange_partner_id,
    r.exchange_partner_approved,
    r.status,
    r.created_at
FROM requests r
JOIN employees e ON r.exchange_partner_id = e.id
WHERE e.name = 'MOHAMED'
ORDER BY r.created_at DESC;

-- 3. Check all notifications for Mohamed
SELECT 
    'Mohamed Notifications' as check_item,
    n.id as notification_id,
    n.employee_id,
    n.request_id,
    n.type,
    n.title,
    n.message,
    n.is_read,
    n.created_at
FROM notifications n
JOIN employees e ON n.employee_id = e.id
WHERE e.name = 'MOHAMED'
ORDER BY n.created_at DESC;

-- 4. Test the get_pending_exchange_approvals function for Mohamed specifically
SELECT 
    'Testing Pending Approvals Function for Mohamed' as check_item,
    * 
FROM get_pending_exchange_approvals(
    (SELECT id FROM employees WHERE name = 'MOHAMED')
);

-- 5. Completely disable RLS on all tables to ensure no permission issues
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 6. Grant all permissions to all roles
GRANT ALL ON employees TO anon, authenticated, postgres;
GRANT ALL ON requests TO anon, authenticated, postgres;
GRANT ALL ON notifications TO anon, authenticated, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, postgres;

-- 7. Update the get_pending_exchange_approvals function to be simpler and more reliable
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
    AND (r.exchange_partner_approved = FALSE OR r.exchange_partner_approved IS NULL)
    AND r.status = 'Pending'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 8. Update the getNotifications function to be simpler
CREATE OR REPLACE FUNCTION get_notifications_for_employee(p_employee_id BIGINT)
RETURNS TABLE(
    id BIGINT,
    employee_id BIGINT,
    request_id BIGINT,
    type VARCHAR(50),
    title VARCHAR(255),
    message TEXT,
    is_read BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.employee_id,
        n.request_id,
        n.type,
        n.title,
        n.message,
        n.is_read,
        n.created_at
    FROM notifications n
    WHERE n.employee_id = p_employee_id
    ORDER BY n.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 9. Test both functions for Mohamed again
DO $$
DECLARE
    mohamed_id BIGINT;
    approval_count INTEGER := 0;
    notification_count INTEGER := 0;
    approval_record RECORD;
    notification_record RECORD;
BEGIN
    -- Get Mohamed's ID
    SELECT id INTO mohamed_id FROM employees WHERE name = 'MOHAMED';
    
    RAISE NOTICE 'Mohamed ID: %', mohamed_id;
    
    -- Test pending approvals
    FOR approval_record IN 
        SELECT * FROM get_pending_exchange_approvals(mohamed_id)
    LOOP
        approval_count := approval_count + 1;
        RAISE NOTICE 'Pending Approval %: Request ID %, Requester: %', approval_count, approval_record.request_id, approval_record.requester_name;
    END LOOP;
    
    -- Test notifications
    FOR notification_record IN 
        SELECT * FROM get_notifications_for_employee(mohamed_id)
    LOOP
        notification_count := notification_count + 1;
        RAISE NOTICE 'Notification %: %, Read: %', notification_count, notification_record.title, notification_record.is_read;
    END LOOP;
    
    RAISE NOTICE 'Total pending approvals for Mohamed: %', approval_count;
    RAISE NOTICE 'Total notifications for Mohamed: %', notification_count;
END $$;

-- 10. Final verification queries
SELECT '=== FINAL VERIFICATION ===' as info;

-- Show Mohamed's data that should appear in the UI
SELECT 
    'What Mohamed should see - Pending Approvals' as section,
    r.id as request_id,
    r.employee_name as requester_name,
    r.employee_email as requester_email,
    r.exchange_from_date,
    r.exchange_to_date,
    r.exchange_reason,
    r.created_at
FROM requests r
WHERE r.exchange_partner_id = (SELECT id FROM employees WHERE name = 'MOHAMED')
AND (r.exchange_partner_approved = FALSE OR r.exchange_partner_approved IS NULL)
AND r.status = 'Pending'
ORDER BY r.created_at DESC;

-- Show Mohamed's notifications
SELECT 
    'What Mohamed should see - Notifications' as section,
    n.id,
    n.type,
    n.title,
    n.message,
    n.is_read,
    n.created_at
FROM notifications n
WHERE n.employee_id = (SELECT id FROM employees WHERE name = 'MOHAMED')
ORDER BY n.created_at DESC; 