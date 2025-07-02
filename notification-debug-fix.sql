-- Notification System Debug and Fix
-- Run this script in your Supabase SQL Editor

-- 1. First, let's check the current state of the database
SELECT '=== DATABASE DIAGNOSTIC ===' as info;

-- Check if notifications table exists and has data
SELECT 
    'Notifications table' as check_item,
    COUNT(*) as count
FROM notifications
UNION ALL
SELECT 
    'Requests with exchange partners' as check_item,
    COUNT(*) as count
FROM requests 
WHERE exchange_partner_id IS NOT NULL
UNION ALL
SELECT 
    'Pending exchange approvals' as check_item,
    COUNT(*) as count
FROM requests 
WHERE exchange_partner_id IS NOT NULL 
AND exchange_partner_approved = FALSE 
AND status = 'Pending';

-- Check the structure of requests table
SELECT 
    'Requests table columns' as check_item,
    string_agg(column_name, ', ') as columns
FROM information_schema.columns 
WHERE table_name = 'requests';

-- Check recent requests with exchange partners
SELECT 
    'Recent exchange requests' as check_item,
    id,
    employee_name,
    employee_email,
    type,
    exchange_partner_id,
    requires_partner_approval,
    status,
    created_at
FROM requests 
WHERE exchange_partner_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- 2. Fix the requests table structure if needed
-- Add employee_id field if it doesn't exist
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS employee_id BIGINT REFERENCES employees(id);

-- Update employee_id for existing requests
UPDATE requests 
SET employee_id = e.id
FROM employees e
WHERE requests.employee_email = e.email
AND requests.employee_id IS NULL;

-- 3. Ensure all required columns exist
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT REFERENCES employees(id),
ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS exchange_partner_notes TEXT,
ADD COLUMN IF NOT EXISTS exchange_from_date DATE,
ADD COLUMN IF NOT EXISTS exchange_to_date DATE,
ADD COLUMN IF NOT EXISTS exchange_reason TEXT,
ADD COLUMN IF NOT EXISTS requires_partner_approval BOOLEAN DEFAULT FALSE;

-- 4. Update existing requests to have proper values
UPDATE requests 
SET 
    exchange_from_date = COALESCE(exchange_from_date, start_date),
    exchange_to_date = COALESCE(exchange_to_date, end_date),
    exchange_reason = COALESCE(exchange_reason, reason),
    requires_partner_approval = TRUE
WHERE exchange_partner_id IS NOT NULL;

-- 5. Drop and recreate the trigger with simpler logic
DROP TRIGGER IF EXISTS trigger_exchange_notification ON requests;
DROP FUNCTION IF EXISTS trigger_create_exchange_notification();

-- Create a simpler trigger function
CREATE OR REPLACE FUNCTION trigger_create_exchange_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Log the trigger execution for debugging
    RAISE NOTICE 'Trigger executed for request % with exchange_partner_id %', 
                 NEW.id, NEW.exchange_partner_id;
    
    -- If this is a request with an exchange partner, create notification
    IF NEW.exchange_partner_id IS NOT NULL THEN
        -- Create notification using the bypass function
        PERFORM create_notification_bypass_rls(
            NEW.exchange_partner_id,
            NEW.id,
            'exchange_approval',
            'Exchange Request Requires Your Approval',
            format('Employee %s (%s) has requested to exchange off days with you. Request ID: %s. Please review and approve/reject this request.', 
                   COALESCE(NEW.employee_name, 'Unknown'), 
                   COALESCE(NEW.employee_email, 'Unknown'), 
                   NEW.id)
        );
        RAISE NOTICE 'Notification created for employee % for request %', NEW.exchange_partner_id, NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_exchange_notification
    AFTER INSERT ON requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_create_exchange_notification();

-- 6. Create a function to manually create notifications for existing requests
CREATE OR REPLACE FUNCTION create_missing_notifications()
RETURNS VOID AS $$
DECLARE
    request_record RECORD;
    notification_count INTEGER := 0;
BEGIN
    -- Loop through all requests that have exchange partners but no notifications
    FOR request_record IN 
        SELECT r.* 
        FROM requests r
        WHERE r.exchange_partner_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 FROM notifications n 
            WHERE n.request_id = r.id 
            AND n.type = 'exchange_approval'
        )
        AND r.status = 'Pending'
    LOOP
        -- Create notification for this request
        PERFORM create_notification_bypass_rls(
            request_record.exchange_partner_id,
            request_record.id,
            'exchange_approval',
            'Exchange Request Requires Your Approval',
            format('Employee %s (%s) has requested to exchange off days with you. Request ID: %s. Please review and approve/reject this request.', 
                   COALESCE(request_record.employee_name, 'Unknown'), 
                   COALESCE(request_record.employee_email, 'Unknown'), 
                   request_record.id)
        );
        notification_count := notification_count + 1;
        RAISE NOTICE 'Created notification for existing request %', request_record.id;
    END LOOP;
    
    RAISE NOTICE 'Created % notifications for existing requests', notification_count;
END;
$$ LANGUAGE plpgsql;

-- 7. Execute the function to create notifications for existing requests
SELECT create_missing_notifications();

-- 8. Update the get_pending_exchange_approvals function to be more robust
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
        COALESCE(r.employee_name, e.name) as requester_name,
        COALESCE(r.employee_email, e.email) as requester_email,
        r.exchange_from_date,
        r.exchange_to_date,
        r.exchange_reason,
        r.created_at
    FROM requests r
    LEFT JOIN employees e ON r.employee_id = e.id
    WHERE r.exchange_partner_id = p_employee_id
    AND r.exchange_partner_approved = FALSE
    AND r.status = 'Pending'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 9. Test the notification system with a manual trigger
DO $$
DECLARE
    test_employee_id BIGINT;
    test_request_id BIGINT;
BEGIN
    -- Get a test employee
    SELECT id INTO test_employee_id FROM employees LIMIT 1;
    
    -- Get a test request
    SELECT id INTO test_request_id FROM requests WHERE exchange_partner_id IS NOT NULL LIMIT 1;
    
    -- Create a test notification if we have both
    IF test_employee_id IS NOT NULL AND test_request_id IS NOT NULL THEN
        PERFORM create_notification_bypass_rls(
            test_employee_id,
            test_request_id,
            'exchange_approval',
            'Test Notification',
            'This is a test notification to verify the system is working.'
        );
        RAISE NOTICE 'Test notification created for employee % and request %', test_employee_id, test_request_id;
    ELSE
        RAISE NOTICE 'Could not create test notification - missing test data';
    END IF;
END $$;

-- 10. Final diagnostic check
SELECT '=== FINAL DIAGNOSTIC ===' as info;

SELECT 
    'Total notifications' as check_item,
    COUNT(*) as count
FROM notifications
UNION ALL
SELECT 
    'Exchange approval notifications' as check_item,
    COUNT(*) as count
FROM notifications
WHERE type = 'exchange_approval'
UNION ALL
SELECT 
    'Unread notifications' as check_item,
    COUNT(*) as count
FROM notifications
WHERE is_read = FALSE;

-- Check notifications for each employee
SELECT 
    'Notifications by employee' as check_item,
    e.name as employee_name,
    e.email as employee_email,
    COUNT(n.id) as notification_count,
    COUNT(CASE WHEN n.is_read = FALSE THEN 1 END) as unread_count
FROM employees e
LEFT JOIN notifications n ON e.id = n.employee_id
GROUP BY e.id, e.name, e.email
ORDER BY notification_count DESC;

-- Check pending exchange approvals
SELECT 
    'Pending exchange approvals' as check_item,
    r.id as request_id,
    r.employee_name as requester_name,
    r.employee_email as requester_email,
    e.name as partner_name,
    e.email as partner_email,
    r.exchange_from_date,
    r.exchange_to_date,
    r.created_at
FROM requests r
JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.exchange_partner_id IS NOT NULL
AND r.exchange_partner_approved = FALSE
AND r.status = 'Pending'
ORDER BY r.created_at DESC; 