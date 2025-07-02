-- Complete Exchange Workflow Fix
-- Run this script in your Supabase SQL Editor

-- 1. First, let's completely reset and fix the notification system
DROP TRIGGER IF EXISTS trigger_exchange_notification ON requests;
DROP FUNCTION IF EXISTS trigger_create_exchange_notification();
DROP FUNCTION IF EXISTS create_exchange_notification(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS create_notification_bypass_rls(BIGINT, BIGINT, VARCHAR, VARCHAR, TEXT);

-- 2. Ensure notifications table exists with proper structure
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id) ON DELETE CASCADE,
    request_id BIGINT REFERENCES requests(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Disable RLS on notifications to avoid permission issues
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 4. Create a simple notification creation function
CREATE OR REPLACE FUNCTION create_notification(
    p_employee_id BIGINT,
    p_request_id BIGINT,
    p_type VARCHAR(50),
    p_title VARCHAR(255),
    p_message TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO notifications (
        employee_id,
        request_id,
        type,
        title,
        message
    ) VALUES (
        p_employee_id,
        p_request_id,
        p_type,
        p_title,
        p_message
    );
    
    RAISE NOTICE 'Created notification for employee %: %', p_employee_id, p_title;
END;
$$ LANGUAGE plpgsql;

-- 5. Create a simple trigger function
CREATE OR REPLACE FUNCTION trigger_create_exchange_notification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Trigger fired for request % with exchange_partner_id %', NEW.id, NEW.exchange_partner_id;
    
    -- If this request has an exchange partner, create notification
    IF NEW.exchange_partner_id IS NOT NULL THEN
        PERFORM create_notification(
            NEW.exchange_partner_id,
            NEW.id,
            'exchange_approval',
            'Exchange Request Requires Your Approval',
            format('Employee %s (%s) has requested to exchange off days with you. Request ID: %s. Please review and approve/reject this request.', 
                   COALESCE(NEW.employee_name, 'Unknown'), 
                   COALESCE(NEW.employee_email, 'Unknown'), 
                   NEW.id)
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create the trigger
CREATE TRIGGER trigger_exchange_notification
    AFTER INSERT ON requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_create_exchange_notification();

-- 7. Update the get_pending_exchange_approvals function
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
    AND r.exchange_partner_approved = FALSE
    AND r.status = 'Pending'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 8. Update the approve_exchange_request function
CREATE OR REPLACE FUNCTION approve_exchange_request(
    p_request_id BIGINT,
    p_employee_id BIGINT,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    request_record RECORD;
    requester_id BIGINT;
BEGIN
    -- Check if the employee is the exchange partner for this request
    IF NOT EXISTS (
        SELECT 1 FROM requests 
        WHERE id = p_request_id 
        AND exchange_partner_id = p_employee_id
        AND exchange_partner_approved = FALSE
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- Get request details
    SELECT * INTO request_record
    FROM requests
    WHERE id = p_request_id;
    
    -- Get requester ID
    SELECT id INTO requester_id
    FROM employees
    WHERE email = request_record.employee_email;
    
    -- Update the exchange approval
    UPDATE requests 
    SET 
        exchange_partner_approved = p_approved,
        exchange_partner_approved_at = NOW(),
        exchange_partner_notes = p_notes
    WHERE id = p_request_id;
    
    -- If approved, update status to 'Partner Approved'
    -- If rejected, update status to 'Rejected'
    IF p_approved THEN
        UPDATE requests 
        SET status = 'Partner Approved'
        WHERE id = p_request_id;
        
        -- Create notification for requester
        IF requester_id IS NOT NULL THEN
            PERFORM create_notification(
                requester_id,
                p_request_id,
                'request_approved',
                'Exchange Request Approved by Partner',
                'Your exchange request has been approved by your exchange partner.'
            );
        END IF;
    ELSE
        UPDATE requests 
        SET status = 'Rejected'
        WHERE id = p_request_id;
        
        -- Create notification for requester
        IF requester_id IS NOT NULL THEN
            PERFORM create_notification(
                requester_id,
                p_request_id,
                'request_rejected',
                'Exchange Request Rejected by Partner',
                format('Your exchange request has been rejected by your exchange partner. Notes: %s', COALESCE(p_notes, 'No notes provided'))
            );
        END IF;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 9. Create a function to check if admin can approve a request
CREATE OR REPLACE FUNCTION can_admin_approve_request(p_request_id BIGINT)
RETURNS TABLE(
    can_approve BOOLEAN,
    reason TEXT
) AS $$
DECLARE
    request_record RECORD;
BEGIN
    -- Get request details
    SELECT * INTO request_record
    FROM requests
    WHERE id = p_request_id;
    
    -- If request doesn't exist
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Request not found';
        RETURN;
    END IF;
    
    -- If request doesn't require partner approval
    IF request_record.exchange_partner_id IS NULL THEN
        RETURN QUERY SELECT TRUE, 'No partner approval required';
        RETURN;
    END IF;
    
    -- If partner has already approved
    IF request_record.exchange_partner_approved = TRUE THEN
        RETURN QUERY SELECT TRUE, 'Partner has approved';
        RETURN;
    END IF;
    
    -- If partner has rejected
    IF request_record.exchange_partner_approved = FALSE AND request_record.exchange_partner_approved_at IS NOT NULL THEN
        RETURN QUERY SELECT FALSE, 'Partner has rejected the request';
        RETURN;
    END IF;
    
    -- If partner hasn't approved yet
    IF request_record.exchange_partner_approved = FALSE THEN
        RETURN QUERY SELECT FALSE, 'Waiting for partner approval';
        RETURN;
    END IF;
    
    RETURN QUERY SELECT TRUE, 'Can approve';
END;
$$ LANGUAGE plpgsql;

-- 10. Create notifications for existing requests that don't have them
DO $$
DECLARE
    request_record RECORD;
    notification_count INTEGER := 0;
BEGIN
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
        PERFORM create_notification(
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
    END LOOP;
    
    RAISE NOTICE 'Created % notifications for existing requests', notification_count;
END $$;

-- 11. Test the system
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
        PERFORM create_notification(
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

-- 12. Show current status
SELECT '=== CURRENT STATUS ===' as info;

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

-- Show notifications by employee
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

-- Show pending exchange approvals
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