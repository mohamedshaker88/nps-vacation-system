-- Notification System Fix for Exchange Partner Notifications
-- Run this script in your Supabase SQL Editor

-- 1. Ensure notifications table exists with proper structure
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id) ON DELETE CASCADE,
    request_id BIGINT REFERENCES requests(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'exchange_approval', 'request_approved', 'request_rejected'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_employee ON notifications(employee_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- 3. Drop existing trigger and function to recreate them properly
DROP TRIGGER IF EXISTS trigger_exchange_notification ON requests;
DROP FUNCTION IF EXISTS trigger_create_exchange_notification();
DROP FUNCTION IF EXISTS create_exchange_notification(BIGINT, BIGINT);

-- 4. Create improved notification function
CREATE OR REPLACE FUNCTION create_exchange_notification(
    p_request_id BIGINT,
    p_exchange_partner_id BIGINT
) RETURNS VOID AS $$
DECLARE
    request_record RECORD;
    requester_name VARCHAR(255);
    requester_email VARCHAR(255);
BEGIN
    -- Get request details
    SELECT * INTO request_record
    FROM requests
    WHERE id = p_request_id;
    
    -- Get requester details
    SELECT name, email INTO requester_name, requester_email
    FROM employees
    WHERE email = request_record.employee_email;
    
    -- Create notification with more detailed information
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
        format('Employee %s (%s) has requested to exchange off days with you. Request ID: %s. Please review and approve/reject this request.', 
               COALESCE(requester_name, 'Unknown'), 
               COALESCE(requester_email, 'Unknown'), 
               p_request_id)
    );
    
    -- Log the notification creation for debugging
    RAISE NOTICE 'Created notification for employee % for request %', p_exchange_partner_id, p_request_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Create improved trigger function
CREATE OR REPLACE FUNCTION trigger_create_exchange_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Log the trigger execution for debugging
    RAISE NOTICE 'Trigger executed for request % with exchange_partner_id % and requires_partner_approval %', 
                 NEW.id, NEW.exchange_partner_id, NEW.requires_partner_approval;
    
    -- If this is a request with an exchange partner, create notification
    IF NEW.exchange_partner_id IS NOT NULL THEN
        -- Create notification regardless of requires_partner_approval flag
        PERFORM create_exchange_notification(NEW.id, NEW.exchange_partner_id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create the trigger
CREATE TRIGGER trigger_exchange_notification
    AFTER INSERT ON requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_create_exchange_notification();

-- 7. Create RLS policies for notifications (if not exists)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Employees can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Employees can update their own notifications" ON notifications;

-- Create new policies
CREATE POLICY "Employees can view their own notifications" ON notifications
    FOR SELECT USING (employee_id IN (
        SELECT id FROM employees WHERE email = current_user
    ));

CREATE POLICY "Employees can update their own notifications" ON notifications
    FOR UPDATE USING (employee_id IN (
        SELECT id FROM employees WHERE email = current_user
    ));

-- 8. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON notifications TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- 9. Function to manually create notifications for existing requests
CREATE OR REPLACE FUNCTION create_notifications_for_existing_requests()
RETURNS VOID AS $$
DECLARE
    request_record RECORD;
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
        PERFORM create_exchange_notification(request_record.id, request_record.exchange_partner_id);
        RAISE NOTICE 'Created notification for existing request %', request_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 10. Execute the function to create notifications for existing requests
SELECT create_notifications_for_existing_requests();

-- 11. Function to get pending exchange approvals with better error handling
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
        e.name,
        e.email,
        r.exchange_from_date,
        r.exchange_to_date,
        r.exchange_reason,
        r.created_at
    FROM requests r
    JOIN employees e ON r.employee_email = e.email
    WHERE r.exchange_partner_id = p_employee_id
    AND r.exchange_partner_approved = FALSE
    AND r.status = 'Pending'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 12. Function to approve exchange request with notification
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
    
    -- If approved, also update the main request status to 'Partner Approved'
    -- If rejected, update to 'Rejected'
    IF p_approved THEN
        UPDATE requests 
        SET status = 'Partner Approved'
        WHERE id = p_request_id;
        
        -- Create notification for requester
        INSERT INTO notifications (
            employee_id,
            request_id,
            type,
            title,
            message
        ) VALUES (
            requester_id,
            p_request_id,
            'request_approved',
            'Exchange Request Approved by Partner',
            'Your exchange request has been approved by your exchange partner.'
        );
    ELSE
        UPDATE requests 
        SET status = 'Rejected'
        WHERE id = p_request_id;
        
        -- Create notification for requester
        INSERT INTO notifications (
            employee_id,
            request_id,
            type,
            title,
            message
        ) VALUES (
            requester_id,
            p_request_id,
            'request_rejected',
            'Exchange Request Rejected by Partner',
            format('Your exchange request has been rejected by your exchange partner. Notes: %s', COALESCE(p_notes, 'No notes provided'))
        );
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 13. Test the notification system
-- This will create a test notification to verify the system is working
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
        INSERT INTO notifications (
            employee_id,
            request_id,
            type,
            title,
            message
        ) VALUES (
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

-- 14. Verify the setup
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