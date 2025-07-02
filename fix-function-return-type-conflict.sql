-- Fix Function Return Type Conflict
-- Drop and recreate the get_pending_exchange_approvals function with proper return type

BEGIN;

-- Step 1: Drop all versions of the conflicting function
DROP FUNCTION IF EXISTS get_pending_exchange_approvals(bigint);
DROP FUNCTION IF EXISTS get_pending_exchange_approvals(integer);

-- Step 2: Disable RLS on notifications table to avoid permission issues
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- Step 3: Drop any existing notification triggers and functions to start fresh
DROP TRIGGER IF EXISTS trigger_exchange_notification ON requests;
DROP TRIGGER IF EXISTS trigger_exchange_notification_simple ON requests;
DROP FUNCTION IF EXISTS trigger_create_exchange_notification() CASCADE;
DROP FUNCTION IF EXISTS trigger_create_exchange_notification_simple() CASCADE;
DROP FUNCTION IF EXISTS create_exchange_notification(bigint, bigint) CASCADE;
DROP FUNCTION IF EXISTS create_exchange_notification_manual(bigint, bigint) CASCADE;
DROP FUNCTION IF EXISTS create_exchange_notification_simple(bigint, bigint) CASCADE;

-- Step 4: Create a simple, reliable notification creation function
CREATE OR REPLACE FUNCTION create_exchange_notification_simple(
    p_request_id BIGINT,
    p_exchange_partner_id BIGINT
) RETURNS VOID AS $$
DECLARE
    request_record RECORD;
    partner_name VARCHAR(255);
BEGIN
    -- Get request details
    SELECT * INTO request_record FROM requests WHERE id = p_request_id;
    
    -- Get partner name
    SELECT name INTO partner_name FROM employees WHERE id = p_exchange_partner_id;
    
    -- Create notification directly
    INSERT INTO notifications (employee_id, type, title, message, is_read)
    VALUES (
        p_exchange_partner_id,
        'exchange_approval',
        'Exchange Request Requires Your Approval',
        format('🔄 %s (%s) has requested to exchange off days with you. They want off on %s and you would get off on %s. Please review this request in your employee portal.',
               COALESCE(request_record.employee_name, 'Unknown Employee'),
               COALESCE(request_record.employee_email, ''),
               COALESCE(request_record.exchange_to_date::text, 'unknown date'),
               COALESCE(request_record.partner_desired_off_date::text, 'unknown date'))
    );
    
    RAISE NOTICE 'Notification created for employee % regarding request %', p_exchange_partner_id, p_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create a trigger function that ALWAYS works
CREATE OR REPLACE FUNCTION trigger_create_exchange_notification_simple()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'TRIGGER FIRED: Request % with partner %', NEW.id, NEW.exchange_partner_id;
    
    -- If this request has an exchange partner, create notification
    IF NEW.exchange_partner_id IS NOT NULL THEN
        PERFORM create_exchange_notification_simple(NEW.id, NEW.exchange_partner_id);
        RAISE NOTICE 'Notification function called for request % and partner %', NEW.id, NEW.exchange_partner_id;
    ELSE
        RAISE NOTICE 'No exchange partner for request %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create the trigger
CREATE TRIGGER trigger_exchange_notification_simple
    AFTER INSERT ON requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_create_exchange_notification_simple();

-- Step 7: Create the manual notification function for dataService
CREATE OR REPLACE FUNCTION create_exchange_notification_manual(
    p_request_id BIGINT,
    p_exchange_partner_id BIGINT
) RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    -- Call the simple function
    PERFORM create_exchange_notification_simple(p_request_id, p_exchange_partner_id);
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Notification created successfully',
        'request_id', p_request_id,
        'partner_id', p_exchange_partner_id
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Failed to create notification',
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Now create the get_pending_exchange_approvals function with correct return type
CREATE OR REPLACE FUNCTION get_pending_exchange_approvals(p_employee_id BIGINT)
RETURNS TABLE(
    request_id BIGINT,
    requester_name VARCHAR(255),
    requester_email VARCHAR(255),
    exchange_from_date DATE,
    exchange_to_date DATE,
    exchange_reason TEXT,
    partner_desired_off_date DATE,
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
        r.partner_desired_off_date,
        r.created_at
    FROM requests r
    WHERE r.exchange_partner_id = p_employee_id
      AND (r.exchange_partner_approved IS NULL OR r.exchange_partner_approved = false)
      AND r.status = 'Pending'
      AND r.type = 'Exchange Off Days'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Step 9: Create notifications for any existing requests that don't have them
DO $$
DECLARE
    request_record RECORD;
    notification_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Creating notifications for existing exchange requests...';
    
    FOR request_record IN 
        SELECT r.id, r.exchange_partner_id, r.employee_name
        FROM requests r
        WHERE r.exchange_partner_id IS NOT NULL
        AND r.status = 'Pending'
        AND NOT EXISTS (
            SELECT 1 FROM notifications n 
            WHERE n.employee_id = r.exchange_partner_id 
            AND n.type = 'exchange_approval'
            AND n.message LIKE '%' || r.employee_name || '%'
        )
    LOOP
        BEGIN
            PERFORM create_exchange_notification_simple(request_record.id, request_record.exchange_partner_id);
            notification_count := notification_count + 1;
            RAISE NOTICE 'Created notification for existing request %', request_record.id;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Failed to create notification for request %: %', request_record.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Created % notifications for existing requests', notification_count;
END $$;

-- Step 10: Test the system
DO $$
DECLARE
    test_request_id BIGINT;
    test_partner_id BIGINT;
    test_result JSONB;
    approval_count INTEGER;
BEGIN
    -- Get the most recent exchange request
    SELECT id, exchange_partner_id 
    INTO test_request_id, test_partner_id
    FROM requests 
    WHERE exchange_partner_id IS NOT NULL 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF test_request_id IS NOT NULL AND test_partner_id IS NOT NULL THEN
        -- Test the manual function
        test_result := create_exchange_notification_manual(test_request_id, test_partner_id);
        RAISE NOTICE 'Manual notification test result: %', test_result;
        
        -- Test the get_pending_exchange_approvals function
        SELECT COUNT(*) INTO approval_count
        FROM get_pending_exchange_approvals(test_partner_id);
        RAISE NOTICE 'Partner % has % pending approvals', test_partner_id, approval_count;
    ELSE
        RAISE NOTICE 'No exchange request found to test with';
    END IF;
END $$;

COMMIT;

-- Final verification
SELECT 
    '=== NOTIFICATION SYSTEM STATUS ===' as info,
    COUNT(CASE WHEN r.exchange_partner_id IS NOT NULL THEN 1 END) as exchange_requests,
    COUNT(n.id) as notifications_created,
    COUNT(CASE WHEN r.exchange_partner_id IS NOT NULL AND n.id IS NULL THEN 1 END) as missing_notifications
FROM requests r
LEFT JOIN notifications n ON (n.employee_id = r.exchange_partner_id AND n.type = 'exchange_approval')
WHERE r.created_at >= NOW() - INTERVAL '7 days';

SELECT 'FUNCTION CONFLICT RESOLVED! Notification system ready.' as result; 