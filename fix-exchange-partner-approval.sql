-- Fix Exchange Partner Approval Workflow
-- This script ensures the partner approval process works correctly

-- 1. Update the approve_exchange_request function to handle status changes properly
CREATE OR REPLACE FUNCTION approve_exchange_request(
    p_request_id INTEGER,
    p_employee_id INTEGER,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    result JSONB;
BEGIN
    -- Get the request
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Check if request exists
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request not found');
    END IF;
    
    -- Check if this employee is the exchange partner
    IF request_row.exchange_partner_id != p_employee_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not the exchange partner for this request');
    END IF;
    
    -- Check if already responded
    IF request_row.exchange_partner_approved IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'You have already responded to this request');
    END IF;
    
    -- Update the request with partner approval
    UPDATE requests 
    SET 
        exchange_partner_approved = p_approved,
        exchange_partner_approved_at = NOW(),
        exchange_partner_notes = p_notes,
        status = CASE 
            WHEN p_approved = true THEN 'Partner Approved'
            ELSE 'Rejected'
        END
    WHERE id = p_request_id;
    
    -- Create notification for requester
    INSERT INTO notifications (employee_id, type, title, message, is_read)
    SELECT 
        request_row.employee_id,
        CASE WHEN p_approved THEN 'exchange_partner_approved' ELSE 'exchange_partner_rejected' END,
        CASE WHEN p_approved THEN 'Exchange Partner Approved' ELSE 'Exchange Partner Rejected' END,
        CASE 
            WHEN p_approved THEN 'Your exchange request for ' || request_row.start_date || ' has been approved by your exchange partner. Waiting for admin approval.'
            ELSE 'Your exchange request for ' || request_row.start_date || ' has been rejected by your exchange partner.'
        END,
        false;
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', CASE WHEN p_approved THEN 'Request approved successfully' ELSE 'Request rejected' END,
        'new_status', CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    );
END;
$$ LANGUAGE plpgsql;

-- 2. Ensure admin approval function correctly handles Partner Approved status
CREATE OR REPLACE FUNCTION can_admin_approve_request(p_request_id INTEGER)
RETURNS TABLE(can_approve BOOLEAN, reason TEXT, debug_info JSONB) AS $$
DECLARE
    request_row requests%ROWTYPE;
    debug_obj JSONB := '{}';
BEGIN
    -- Get the request details
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Build debug info
    debug_obj := jsonb_build_object(
        'request_id', p_request_id,
        'request_status', request_row.status,
        'exchange_partner_id', request_row.exchange_partner_id,
        'exchange_partner_approved', request_row.exchange_partner_approved,
        'exchange_partner_approved_at', request_row.exchange_partner_approved_at
    );
    
    -- If request doesn't exist
    IF request_row.id IS NULL THEN
        RETURN QUERY SELECT false, 'Request not found', debug_obj;
        RETURN;
    END IF;
    
    -- If request is already processed
    IF request_row.status IN ('Approved', 'Rejected') THEN
        RETURN QUERY SELECT false, 'Request already processed', debug_obj;
        RETURN;
    END IF;
    
    -- If it's not an exchange request, admin can approve
    IF request_row.exchange_partner_id IS NULL THEN
        RETURN QUERY SELECT true, 'Regular leave request - can approve', debug_obj;
        RETURN;
    END IF;
    
    -- For exchange requests, check partner approval
    IF request_row.exchange_partner_approved IS NULL THEN
        RETURN QUERY SELECT false, 'Waiting for exchange partner approval', debug_obj;
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_approved = false THEN
        RETURN QUERY SELECT false, 'Exchange partner rejected the request', debug_obj;
        RETURN;
    END IF;
    
    -- Partner approved, admin can approve
    RETURN QUERY SELECT true, 'Exchange partner approved - admin can approve', debug_obj;
END;
$$ LANGUAGE plpgsql;

-- 3. Create a function to manually fix any requests stuck in wrong status
CREATE OR REPLACE FUNCTION fix_partner_approved_requests()
RETURNS TABLE(
    request_id INTEGER,
    old_status TEXT,
    new_status TEXT,
    message TEXT
) AS $$
BEGIN
    -- Find requests where partner approved but status is still Pending
    RETURN QUERY
    UPDATE requests 
    SET status = 'Partner Approved'
    WHERE exchange_partner_approved = true 
      AND status = 'Pending'
      AND exchange_partner_id IS NOT NULL
    RETURNING id, 'Pending', 'Partner Approved', 'Fixed status for partner approved request';
END;
$$ LANGUAGE plpgsql;

-- 4. Run the fix for any existing broken requests
SELECT * FROM fix_partner_approved_requests();

-- 5. Show current state of all exchange requests
SELECT 
    r.id,
    r.employee_name,
    r.start_date,
    r.status,
    r.exchange_partner_id,
    ep.name as partner_name,
    r.exchange_partner_approved,
    r.exchange_partner_approved_at,
    CASE 
        WHEN r.exchange_partner_id IS NULL THEN 'Not an exchange request'
        WHEN r.exchange_partner_approved IS NULL THEN 'Waiting for partner approval'
        WHEN r.exchange_partner_approved = true AND r.status = 'Pending' THEN 'NEEDS STATUS FIX'
        WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN 'Ready for admin approval'
        WHEN r.exchange_partner_approved = false THEN 'Partner rejected'
        ELSE 'Unknown state'
    END as workflow_status
FROM requests r
LEFT JOIN employees ep ON ep.id = r.exchange_partner_id
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC;

-- 6. Show notifications for partners
SELECT 
    n.id,
    n.employee_id,
    e.name as employee_name,
    n.type,
    n.title,
    n.message,
    n.is_read,
    n.created_at
FROM notifications n
JOIN employees e ON e.id = n.employee_id
WHERE n.type LIKE '%exchange%'
ORDER BY n.created_at DESC;

COMMIT; 