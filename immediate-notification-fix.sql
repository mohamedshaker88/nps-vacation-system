-- Immediate Notification Fix for Engy-Mohamed Request
-- Run this script in your Supabase SQL Editor

-- 1. First, let's check what's in the database
SELECT '=== CURRENT STATE ===' as info;

-- Check the specific request between Engy and Mohamed
SELECT 
    'Engy-Mohamed Request' as check_item,
    r.id,
    r.employee_name,
    r.employee_email,
    r.type,
    r.exchange_partner_id,
    r.status,
    r.created_at,
    e.name as partner_name,
    e.email as partner_email
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE (r.employee_name ILIKE '%engy%' OR r.employee_email ILIKE '%engy%')
AND (e.name ILIKE '%mohamed%' OR e.email ILIKE '%mohamed%')
ORDER BY r.created_at DESC;

-- Check all recent requests with exchange partners
SELECT 
    'Recent Exchange Requests' as check_item,
    r.id,
    r.employee_name,
    r.employee_email,
    r.type,
    r.exchange_partner_id,
    r.status,
    r.created_at,
    e.name as partner_name,
    e.email as partner_email
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.exchange_partner_id IS NOT NULL
ORDER BY r.created_at DESC
LIMIT 10;

-- Check if notifications exist
SELECT 
    'Notifications for Mohamed' as check_item,
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
WHERE e.name ILIKE '%mohamed%' OR e.email ILIKE '%mohamed%'
ORDER BY n.created_at DESC;

-- 2. Get Mohamed's employee ID
SELECT 
    'Mohamed Employee Info' as check_item,
    id,
    name,
    email
FROM employees
WHERE name ILIKE '%mohamed%' OR email ILIKE '%mohamed%';

-- 3. Get Engy's employee ID
SELECT 
    'Engy Employee Info' as check_item,
    id,
    name,
    email
FROM employees
WHERE name ILIKE '%engy%' OR email ILIKE '%engy%';

-- 4. Manually create notification for the Engy-Mohamed request
DO $$
DECLARE
    engy_request_id BIGINT;
    mohamed_id BIGINT;
    notification_created BOOLEAN := FALSE;
BEGIN
    -- Get the most recent request from Engy to Mohamed
    SELECT r.id INTO engy_request_id
    FROM requests r
    JOIN employees e ON r.exchange_partner_id = e.id
    WHERE (r.employee_name ILIKE '%engy%' OR r.employee_email ILIKE '%engy%')
    AND (e.name ILIKE '%mohamed%' OR e.email ILIKE '%mohamed%')
    ORDER BY r.created_at DESC
    LIMIT 1;
    
    -- Get Mohamed's ID
    SELECT id INTO mohamed_id
    FROM employees
    WHERE name ILIKE '%mohamed%' OR email ILIKE '%mohamed%'
    LIMIT 1;
    
    -- Create notification if we found both
    IF engy_request_id IS NOT NULL AND mohamed_id IS NOT NULL THEN
        -- Check if notification already exists
        IF NOT EXISTS (
            SELECT 1 FROM notifications 
            WHERE request_id = engy_request_id 
            AND employee_id = mohamed_id 
            AND type = 'exchange_approval'
        ) THEN
            INSERT INTO notifications (
                employee_id,
                request_id,
                type,
                title,
                message
            ) VALUES (
                mohamed_id,
                engy_request_id,
                'exchange_approval',
                'Exchange Request Requires Your Approval',
                'Employee Engy has requested to exchange off days with you. Please review and approve/reject this request.'
            );
            notification_created := TRUE;
            RAISE NOTICE 'Created notification for Mohamed (ID: %) for request %', mohamed_id, engy_request_id;
        ELSE
            RAISE NOTICE 'Notification already exists for request %', engy_request_id;
        END IF;
    ELSE
        RAISE NOTICE 'Could not find Engy request or Mohamed employee. Request ID: %, Mohamed ID: %', engy_request_id, mohamed_id;
    END IF;
END $$;

-- 5. Test the trigger manually
DO $$
DECLARE
    test_request RECORD;
BEGIN
    -- Get the most recent request with exchange partner
    SELECT * INTO test_request
    FROM requests
    WHERE exchange_partner_id IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF test_request.id IS NOT NULL THEN
        RAISE NOTICE 'Testing trigger for request % with partner %', test_request.id, test_request.exchange_partner_id;
        
        -- Manually call the trigger function
        PERFORM trigger_create_exchange_notification();
    ELSE
        RAISE NOTICE 'No requests with exchange partners found';
    END IF;
END $$;

-- 6. Check if the trigger is working
SELECT 
    'Trigger Status' as check_item,
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_exchange_notification';

-- 7. Final check - show all notifications for Mohamed
SELECT 
    'Final Notifications for Mohamed' as check_item,
    n.id,
    n.employee_id,
    n.request_id,
    n.type,
    n.title,
    n.message,
    n.is_read,
    n.created_at,
    e.name as employee_name,
    e.email as employee_email
FROM notifications n
JOIN employees e ON n.employee_id = e.id
WHERE e.name ILIKE '%mohamed%' OR e.email ILIKE '%mohamed%'
ORDER BY n.created_at DESC;

-- 8. Show pending approvals for Mohamed
SELECT 
    'Pending Approvals for Mohamed' as check_item,
    r.id as request_id,
    r.employee_name as requester_name,
    r.employee_email as requester_email,
    r.exchange_from_date,
    r.exchange_to_date,
    r.exchange_reason,
    r.created_at
FROM requests r
JOIN employees e ON r.exchange_partner_id = e.id
WHERE (e.name ILIKE '%mohamed%' OR e.email ILIKE '%mohamed%')
AND r.exchange_partner_approved = FALSE
AND r.status = 'Pending'
ORDER BY r.created_at DESC; 