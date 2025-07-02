-- Fix Type Mismatch Error
-- This fixes the bigint vs integer issue in fix_partner_approved_requests function

-- Drop the problematic function
DROP FUNCTION IF EXISTS fix_partner_approved_requests();

-- Recreate with correct types
CREATE OR REPLACE FUNCTION fix_partner_approved_requests()
RETURNS TABLE(
    request_id BIGINT,  -- Changed from INTEGER to BIGINT
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
    RETURNING id, 'Pending'::TEXT, 'Partner Approved'::TEXT, 'Fixed status for partner approved request'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Also fix the can_admin_approve_request function to use BIGINT consistently
CREATE OR REPLACE FUNCTION can_admin_approve_request(p_request_id BIGINT)  -- Changed from INTEGER to BIGINT
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

-- Fix approve_exchange_request function to use BIGINT
CREATE OR REPLACE FUNCTION approve_exchange_request(
    p_request_id BIGINT,  -- Changed from INTEGER to BIGINT
    p_employee_id BIGINT,
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
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', CASE WHEN p_approved THEN 'Request approved successfully' ELSE 'Request rejected' END,
        'new_status', CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    );
END;
$$ LANGUAGE plpgsql;

-- Fix get_exchange_request_status function to use BIGINT
CREATE OR REPLACE FUNCTION get_exchange_request_status(p_request_id BIGINT)  -- Changed from INTEGER to BIGINT
RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    partner_name TEXT;
    result JSONB;
BEGIN
    -- Get the request first
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Get partner name separately if there is a partner
    IF request_row.exchange_partner_id IS NOT NULL THEN
        SELECT name INTO partner_name 
        FROM employees 
        WHERE id = request_row.exchange_partner_id;
    END IF;
    
    result := jsonb_build_object(
        'request_id', request_row.id,
        'status', request_row.status,
        'exchange_partner_id', request_row.exchange_partner_id,
        'exchange_partner_name', partner_name,
        'exchange_partner_approved', request_row.exchange_partner_approved,
        'exchange_partner_approved_at', request_row.exchange_partner_approved_at,
        'can_admin_approve', CASE 
            WHEN request_row.exchange_partner_id IS NULL THEN true
            WHEN request_row.exchange_partner_approved = true THEN true
            ELSE false
        END
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Now run the fix for any broken requests
SELECT * FROM fix_partner_approved_requests();

-- Show current status
SELECT 
    'Fixed Type Mismatch - Current Status:' as info,
    r.id,
    r.employee_name,
    r.status,
    r.exchange_partner_approved,
    CASE 
        WHEN r.exchange_partner_approved IS NULL THEN '⏳ Waiting for partner'
        WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN '✅ Ready for admin'
        WHEN r.exchange_partner_approved = false THEN '❌ Partner rejected'
        WHEN r.status = 'Approved' THEN '🎉 Approved'
        ELSE '❓ Unknown status'
    END as workflow_status
FROM requests r
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC;

COMMIT; 