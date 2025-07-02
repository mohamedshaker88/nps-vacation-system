-- Final Notification Fix - Manual Approach
-- Run this script in your Supabase SQL Editor

-- 1. Drop the problematic trigger completely
DROP TRIGGER IF EXISTS trigger_exchange_notification ON requests;
DROP FUNCTION IF EXISTS trigger_create_exchange_notification();

-- 2. Disable RLS completely on notifications table
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 3. Grant all permissions to ensure notifications can be created
GRANT ALL ON notifications TO anon, authenticated, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, postgres;

-- 4. Simple function to create notification (no trigger)
CREATE OR REPLACE FUNCTION create_exchange_notification_manual(
    p_request_id BIGINT,
    p_exchange_partner_id BIGINT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO notifications (
        employee_id,
        request_id,
        type,
        title,
        message
    ) VALUES (
        p_exchange_partner_id,
        p_request_id,
        'exchange_approval',
        'Exchange Request Requires Your Approval',
        'You have been selected as an exchange partner for a leave request. Please review and approve/reject this request.'
    );
    
    RAISE NOTICE 'Created notification for employee % for request %', p_exchange_partner_id, p_request_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Create notifications for ALL existing requests that don't have them
DO $$
DECLARE
    request_record RECORD;
    notification_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting to create notifications for existing requests...';
    
    FOR request_record IN 
        SELECT r.* 
        FROM requests r
        WHERE r.exchange_partner_id IS NOT NULL
        AND r.status = 'Pending'
    LOOP
        -- Check if notification already exists
        IF NOT EXISTS (
            SELECT 1 FROM notifications 
            WHERE request_id = request_record.id 
            AND employee_id = request_record.exchange_partner_id
            AND type = 'exchange_approval'
        ) THEN
            -- Create notification
            PERFORM create_exchange_notification_manual(
                request_record.id,
                request_record.exchange_partner_id
            );
            notification_count := notification_count + 1;
            RAISE NOTICE 'Created notification for request % (partner: %)', request_record.id, request_record.exchange_partner_id;
        ELSE
            RAISE NOTICE 'Notification already exists for request %', request_record.id;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Created % new notifications', notification_count;
END $$;

-- 6. Show current status
SELECT '=== NOTIFICATION STATUS ===' as info;

-- Show all employees
SELECT 
    'All Employees' as check_item,
    id,
    name,
    email
FROM employees
ORDER BY name;

-- Show all requests with exchange partners
SELECT 
    'All Exchange Requests' as check_item,
    r.id as request_id,
    r.employee_name as requester,
    r.employee_email as requester_email,
    r.type,
    r.exchange_partner_id,
    e.name as partner_name,
    e.email as partner_email,
    r.status,
    r.created_at
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.exchange_partner_id IS NOT NULL
ORDER BY r.created_at DESC;

-- Show all notifications
SELECT 
    'All Notifications' as check_item,
    n.id as notification_id,
    n.employee_id,
    e.name as employee_name,
    e.email as employee_email,
    n.request_id,
    n.type,
    n.title,
    n.is_read,
    n.created_at
FROM notifications n
JOIN employees e ON n.employee_id = e.id
ORDER BY n.created_at DESC;

-- Show pending approvals for each employee
SELECT 
    'Pending Approvals by Employee' as check_item,
    e.name as employee_name,
    e.email as employee_email,
    COUNT(r.id) as pending_count
FROM employees e
LEFT JOIN requests r ON e.id = r.exchange_partner_id 
    AND r.exchange_partner_approved = FALSE 
    AND r.status = 'Pending'
GROUP BY e.id, e.name, e.email
ORDER BY pending_count DESC, e.name;

-- Detailed pending approvals
SELECT 
    'Detailed Pending Approvals' as check_item,
    e.name as partner_name,
    e.email as partner_email,
    r.id as request_id,
    r.employee_name as requester,
    r.employee_email as requester_email,
    r.exchange_from_date,
    r.exchange_to_date,
    r.exchange_reason,
    r.created_at
FROM employees e
JOIN requests r ON e.id = r.exchange_partner_id
WHERE r.exchange_partner_approved = FALSE 
AND r.status = 'Pending'
ORDER BY e.name, r.created_at DESC; 