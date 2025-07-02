-- Debug Exchange Partner Notification Issue
-- This script will help identify why notifications aren't being sent

-- 1. Check if the trigger exists and is working
SELECT 
    'Checking if notification trigger exists:' as info,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%notification%' 
   OR trigger_name LIKE '%exchange%';

-- 2. Check recent exchange requests
SELECT 
    '=== RECENT EXCHANGE REQUESTS ===' as info,
    r.id,
    r.employee_name as requester,
    r.employee_email as requester_email,
    r.exchange_partner_id,
    e.name as partner_name,
    e.email as partner_email,
    r.status,
    r.created_at,
    r.partner_desired_off_date,
    CASE 
        WHEN r.exchange_partner_id IS NULL THEN '❌ No partner selected'
        WHEN e.id IS NULL THEN '❌ Partner not found in employees table'
        ELSE '✅ Partner found'
    END as partner_status
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC
LIMIT 10;

-- 3. Check notifications for exchange requests
SELECT 
    '=== NOTIFICATIONS FOR EXCHANGE REQUESTS ===' as info,
    n.id as notification_id,
    n.employee_id,
    e.name as employee_name,
    e.email as employee_email,
    n.type,
    n.title,
    n.message,
    n.is_read,
    n.created_at,
    r.id as request_id,
    r.employee_name as requester
FROM notifications n
LEFT JOIN employees e ON n.employee_id = e.id
LEFT JOIN requests r ON n.request_id = r.id
WHERE n.type LIKE '%exchange%'
ORDER BY n.created_at DESC
LIMIT 10;

-- 4. Check if there are any pending exchange approvals
SELECT 
    '=== CHECKING PENDING APPROVALS FUNCTION ===' as info;

-- Test the get_pending_exchange_approvals function for each employee
DO $$
DECLARE
    emp_record RECORD;
    approvals_count INTEGER;
BEGIN
    FOR emp_record IN SELECT id, name, email FROM employees LOOP
        SELECT COUNT(*) INTO approvals_count
        FROM get_pending_exchange_approvals(emp_record.id);
        
        IF approvals_count > 0 THEN
            RAISE NOTICE 'Employee % (%) has % pending approvals', 
                         emp_record.name, emp_record.email, approvals_count;
        END IF;
    END LOOP;
END $$;

-- 5. Manual test - create a test notification
DO $$
DECLARE
    test_employee_id BIGINT;
    test_request_id BIGINT;
BEGIN
    -- Get the most recent exchange request
    SELECT id INTO test_request_id 
    FROM requests 
    WHERE exchange_partner_id IS NOT NULL 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    -- Get the exchange partner ID
    SELECT exchange_partner_id INTO test_employee_id 
    FROM requests 
    WHERE id = test_request_id;
    
    IF test_employee_id IS NOT NULL AND test_request_id IS NOT NULL THEN
        -- Try to create a test notification
        BEGIN
            INSERT INTO notifications (employee_id, request_id, type, title, message, is_read)
            VALUES (
                test_employee_id,
                test_request_id,
                'exchange_approval',
                'TEST: Exchange Request Approval Needed',
                format('This is a test notification for request ID %s', test_request_id),
                false
            );
            RAISE NOTICE 'SUCCESS: Test notification created for employee % and request %', 
                         test_employee_id, test_request_id;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: Failed to create test notification: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'No exchange request found to test with';
    END IF;
END $$;

-- 6. Check if the dataService function exists
SELECT 
    '=== CHECKING DATABASE FUNCTIONS ===' as info,
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name LIKE '%exchange%' 
   OR routine_name LIKE '%notification%'
ORDER BY routine_name;

-- 7. Test if we can manually call notification functions
DO $$
DECLARE
    test_result BOOLEAN;
    test_employee_id BIGINT;
    test_request_id BIGINT;
BEGIN
    -- Get test data
    SELECT id INTO test_request_id 
    FROM requests 
    WHERE exchange_partner_id IS NOT NULL 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    SELECT exchange_partner_id INTO test_employee_id 
    FROM requests 
    WHERE id = test_request_id;
    
    IF test_employee_id IS NOT NULL AND test_request_id IS NOT NULL THEN
        -- Try different notification creation functions
        BEGIN
            -- Check if create_exchange_notification exists
            IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_exchange_notification') THEN
                PERFORM create_exchange_notification(test_request_id, test_employee_id);
                RAISE NOTICE 'Called create_exchange_notification successfully';
            ELSE
                RAISE NOTICE 'Function create_exchange_notification does not exist';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error calling create_exchange_notification: %', SQLERRM;
        END;

        BEGIN
            -- Check if create_exchange_notification_manual exists
            IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_exchange_notification_manual') THEN
                PERFORM create_exchange_notification_manual(test_request_id, test_employee_id);
                RAISE NOTICE 'Called create_exchange_notification_manual successfully';
            ELSE
                RAISE NOTICE 'Function create_exchange_notification_manual does not exist';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error calling create_exchange_notification_manual: %', SQLERRM;
        END;
    END IF;
END $$;

-- 8. Show the most recent requests and their notification status
SELECT 
    '=== REQUEST vs NOTIFICATION STATUS ===' as info,
    r.id as request_id,
    r.employee_name,
    r.exchange_partner_id,
    e.name as partner_name,
    r.created_at as request_created,
    COUNT(n.id) as notification_count,
    MAX(n.created_at) as last_notification,
    CASE 
        WHEN COUNT(n.id) = 0 THEN '❌ NO NOTIFICATIONS'
        ELSE '✅ Has notifications'
    END as notification_status
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
LEFT JOIN notifications n ON (n.request_id = r.id AND n.employee_id = r.exchange_partner_id)
WHERE r.exchange_partner_id IS NOT NULL
  AND r.created_at >= NOW() - INTERVAL '7 days'
GROUP BY r.id, r.employee_name, r.exchange_partner_id, e.name, r.created_at
ORDER BY r.created_at DESC;

-- 9. Check RLS policies on notifications table
SELECT 
    '=== RLS POLICIES ON NOTIFICATIONS ===' as info,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'notifications';

-- 10. Check if RLS is enabled
SELECT 
    '=== RLS STATUS ===' as info,
    schemaname,
    tablename,
    rowsecurity,
    forcerowsecurity
FROM pg_tables 
WHERE tablename = 'notifications';

SELECT 'DEBUG COMPLETE - Check the output above for issues' as result; 