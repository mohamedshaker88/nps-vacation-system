-- Fix RLS Policies for Notifications Table
-- Run this script in your Supabase SQL Editor

-- 1. Temporarily disable RLS on notifications table to allow trigger to work
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies if they exist
DROP POLICY IF EXISTS "Employees can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Employees can update their own notifications" ON notifications;

-- 3. Re-enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 4. Create new policies that allow the trigger to work
-- Policy for inserting notifications (allows the trigger to work)
CREATE POLICY "Allow notification insertion" ON notifications
    FOR INSERT WITH CHECK (true);

-- Policy for viewing notifications
CREATE POLICY "Employees can view their own notifications" ON notifications
    FOR SELECT USING (
        employee_id IN (
            SELECT id FROM employees WHERE email = current_user
        )
    );

-- Policy for updating notifications (marking as read)
CREATE POLICY "Employees can update their own notifications" ON notifications
    FOR UPDATE USING (
        employee_id IN (
            SELECT id FROM employees WHERE email = current_user
        )
    );

-- 5. Grant necessary permissions to the authenticated role
GRANT ALL ON notifications TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- 6. Create a function to bypass RLS for notification creation
CREATE OR REPLACE FUNCTION create_notification_bypass_rls(
    p_employee_id BIGINT,
    p_request_id BIGINT,
    p_type VARCHAR(50),
    p_title VARCHAR(255),
    p_message TEXT
) RETURNS VOID AS $$
BEGIN
    -- This function runs with elevated privileges to bypass RLS
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Update the notification creation function to use the bypass function
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
    
    -- Create notification using the bypass function
    PERFORM create_notification_bypass_rls(
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

-- 8. Update the approval function to use the bypass function
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
        
        -- Create notification for requester using bypass function
        PERFORM create_notification_bypass_rls(
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
        
        -- Create notification for requester using bypass function
        PERFORM create_notification_bypass_rls(
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

-- 9. Test the notification system
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

-- 10. Verify the setup
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