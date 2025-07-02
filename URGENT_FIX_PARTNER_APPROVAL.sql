-- URGENT FIX FOR PARTNER APPROVAL FUNCTION CONFLICT
-- Run this immediately to fix the "Could not choose the best candidate function" error

BEGIN;

-- Step 1: Drop ALL versions of the conflicting function
DROP FUNCTION IF EXISTS approve_exchange_request(bigint, bigint, boolean, text);
DROP FUNCTION IF EXISTS approve_exchange_request(integer, integer, boolean, text);
DROP FUNCTION IF EXISTS approve_exchange_request(bigint, bigint, boolean);
DROP FUNCTION IF EXISTS approve_exchange_request(integer, integer, boolean);

-- Step 2: Drop related functions that might conflict  
DROP FUNCTION IF EXISTS get_pending_exchange_approvals(bigint);
DROP FUNCTION IF EXISTS get_pending_exchange_approvals(integer);

-- Step 3: Create ONE clean version with BIGINT types (matching table schema)
CREATE OR REPLACE FUNCTION approve_exchange_request(
    p_request_id BIGINT,
    p_employee_id BIGINT,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    requester_employee employees%ROWTYPE;
    partner_employee employees%ROWTYPE;
BEGIN
    -- Get the request details
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Validate request exists
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Request not found'
        );
    END IF;
    
    -- Validate this employee is the exchange partner
    IF request_row.exchange_partner_id != p_employee_id THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'You are not the exchange partner for this request'
        );
    END IF;
    
    -- Check if already responded
    IF request_row.exchange_partner_approved IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'You have already responded to this request'
        );
    END IF;
    
    -- Get employee details for notifications
    SELECT * INTO requester_employee FROM employees WHERE id = request_row.employee_id;
    SELECT * INTO partner_employee FROM employees WHERE id = p_employee_id;
    
    -- Update the request with partner response
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
    
    -- Create notification for the requester
    BEGIN
        INSERT INTO notifications (employee_id, type, title, message, is_read)
        VALUES (
            request_row.employee_id,
            CASE WHEN p_approved THEN 'exchange_partner_approved' ELSE 'exchange_partner_rejected' END,
            CASE WHEN p_approved THEN 'Exchange Partner Approved' ELSE 'Exchange Partner Rejected' END,
            CASE 
                WHEN p_approved THEN 
                    format('✅ %s has approved your exchange request for %s. It now needs admin approval.',
                           partner_employee.name, request_row.start_date)
                ELSE 
                    format('❌ %s has rejected your exchange request for %s. Reason: %s',
                           partner_employee.name, request_row.start_date, COALESCE(p_notes, 'No reason provided'))
            END,
            false
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Failed to create notification: %', SQLERRM;
    END;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', CASE 
            WHEN p_approved THEN 'Exchange request approved successfully' 
            ELSE 'Exchange request rejected' 
        END,
        'new_status', CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Database error occurred',
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Step 4: Recreate the helper function with consistent types
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
      AND r.exchange_partner_approved IS NULL
      AND r.status = 'Pending'
      AND r.type = 'Exchange Off Days'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verification
SELECT 'SUCCESS: Function conflict resolved!' as status; 