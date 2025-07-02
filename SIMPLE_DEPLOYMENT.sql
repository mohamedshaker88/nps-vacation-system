-- SIMPLE DEPLOYMENT SCRIPT - Clean and Deploy Exchange System
-- This script safely deploys the exchange system from scratch

-- Clean slate: Drop everything first
DO $$ 
DECLARE
    func_name TEXT;
BEGIN
    -- Drop all functions that might conflict
    FOR func_name IN 
        SELECT routine_name 
        FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name IN (
            'can_admin_approve_request',
            'approve_exchange_request', 
            'get_exchange_request_status',
            'admin_approve_request_safe',
            'swap_work_schedules_bidirectional',
            'get_or_create_work_schedule',
            'update_schedules_on_approval',
            'update_request_status_and_schedules_bidirectional',
            'fix_partner_approved_requests'
        )
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_name || ' CASCADE';
    END LOOP;
END $$;

-- Drop any existing triggers
DROP TRIGGER IF EXISTS trigger_update_schedule_on_approval ON requests;

-- Ensure required tables exist
CREATE TABLE IF NOT EXISTS work_schedules (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id),
    week_start_date DATE NOT NULL,
    monday_status VARCHAR(20) DEFAULT 'working',
    tuesday_status VARCHAR(20) DEFAULT 'working', 
    wednesday_status VARCHAR(20) DEFAULT 'working',
    thursday_status VARCHAR(20) DEFAULT 'working',
    friday_status VARCHAR(20) DEFAULT 'working',
    saturday_status VARCHAR(20) DEFAULT 'off',
    sunday_status VARCHAR(20) DEFAULT 'off',
    UNIQUE(employee_id, week_start_date)
);

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id),
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns to requests table
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT REFERENCES employees(id);
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_from_date DATE;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_to_date DATE;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_reason TEXT;

-- CREATE CORE FUNCTIONS

-- 1. Admin approval check
CREATE FUNCTION can_admin_approve_request(p_request_id BIGINT)
RETURNS TABLE(can_approve BOOLEAN, reason TEXT) AS $$
DECLARE
    request_row requests%ROWTYPE;
BEGIN
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    IF request_row.id IS NULL THEN
        RETURN QUERY SELECT false, 'Request not found';
        RETURN;
    END IF;
    
    IF request_row.status IN ('Approved', 'Rejected') THEN
        RETURN QUERY SELECT false, 'Request already processed';
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_id IS NULL THEN
        RETURN QUERY SELECT true, 'Regular request - can approve';
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_approved = true THEN
        RETURN QUERY SELECT true, 'Partner approved - admin can approve';
        RETURN;
    END IF;
    
    RETURN QUERY SELECT false, 'Waiting for partner approval';
END;
$$ LANGUAGE plpgsql;

-- 2. Safe admin approval with detailed error handling
CREATE FUNCTION admin_approve_request_safe(
    p_request_id BIGINT,
    p_new_status TEXT
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    approval_result RECORD;
BEGIN
    -- Get request
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;
    
    -- For approvals, check if allowed
    IF p_new_status = 'Approved' THEN
        SELECT can_approve, reason INTO approval_result FROM can_admin_approve_request(p_request_id);
        IF NOT approval_result.can_approve THEN
            RETURN jsonb_build_object('success', false, 'error', approval_result.reason);
        END IF;
    END IF;
    
    -- Update status
    UPDATE requests SET status = p_new_status WHERE id = p_request_id;
    
    -- Check if update worked
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Update failed');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'message', 'Status updated to ' || p_new_status);
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- 3. Partner approval function
CREATE FUNCTION approve_exchange_request(
    p_request_id BIGINT,
    p_employee_id BIGINT,
    p_approved BOOLEAN
) RETURNS JSONB AS $$
BEGIN
    UPDATE requests 
    SET 
        exchange_partner_approved = p_approved,
        exchange_partner_approved_at = NOW(),
        status = CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    WHERE id = p_request_id AND exchange_partner_id = p_employee_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request not found or not authorized');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'message', 'Response recorded');
END;
$$ LANGUAGE plpgsql;

-- 4. Simple trigger for notifications (without complex schedule logic)
CREATE FUNCTION simple_approval_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Just log approvals for now
    IF NEW.status = 'Approved' AND (OLD.status IS NULL OR OLD.status != 'Approved') THEN
        RAISE NOTICE 'Request % approved successfully', NEW.id;
        
        -- Try to insert a simple notification
        BEGIN
            INSERT INTO notifications (employee_id, type, title, message, is_read)
            VALUES (NEW.employee_id, 'request_approved', 'Request Approved', 
                   'Your request has been approved!', false);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Notification failed: %', SQLERRM;
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_simple_approval
    AFTER UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION simple_approval_trigger();

-- Fix any existing partner-approved requests
UPDATE requests 
SET status = 'Partner Approved'
WHERE exchange_partner_approved = true 
  AND status = 'Pending';

-- Show results
SELECT 'SIMPLE DEPLOYMENT COMPLETED' as result;

SELECT 
    r.id,
    r.employee_name,
    r.status,
    r.exchange_partner_approved,
    CASE 
        WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN '✅ Ready for admin'
        WHEN r.exchange_partner_approved IS NULL THEN '⏳ Waiting for partner'
        WHEN r.status = 'Approved' THEN '🎉 Approved'
        ELSE r.status
    END as workflow_status
FROM requests r
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC; 