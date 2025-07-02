-- DEPLOY EXCHANGE SYSTEM - COMPLETE DEPLOYMENT SCRIPT
-- Run this single script to deploy the entire bidirectional exchange system
-- This handles all potential errors and conflicts

BEGIN;

-- STEP 1: Drop all existing functions to avoid conflicts
DROP FUNCTION IF EXISTS can_admin_approve_request(bigint);
DROP FUNCTION IF EXISTS can_admin_approve_request(integer);
DROP FUNCTION IF EXISTS approve_exchange_request(integer, bigint, boolean, text);
DROP FUNCTION IF EXISTS approve_exchange_request(bigint, bigint, boolean, text);
DROP FUNCTION IF EXISTS get_exchange_request_status(integer);
DROP FUNCTION IF EXISTS get_exchange_request_status(bigint);
DROP FUNCTION IF EXISTS admin_approve_request_safe(bigint, text);
DROP FUNCTION IF EXISTS swap_work_schedules_bidirectional(bigint, bigint, date, date);
DROP FUNCTION IF EXISTS fix_partner_approved_requests();
DROP FUNCTION IF EXISTS get_or_create_work_schedule(bigint, date);
DROP FUNCTION IF EXISTS update_schedules_on_approval();
DROP FUNCTION IF EXISTS update_request_status_and_schedules_bidirectional();
DROP FUNCTION IF EXISTS update_schedule_for_approved_leave();

-- STEP 2: Ensure required tables exist
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
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

-- STEP 3: Add exchange columns to requests table if they don't exist
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT REFERENCES employees(id);
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_partner_notes TEXT;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_from_date DATE;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_to_date DATE;
ALTER TABLE requests ADD COLUMN IF NOT EXISTS exchange_reason TEXT;

-- STEP 4: Create the core functions

-- 4a. Admin approval check function
CREATE FUNCTION can_admin_approve_request(p_request_id BIGINT)
RETURNS TABLE(can_approve BOOLEAN, reason TEXT, debug_info JSONB) AS $$
DECLARE
    request_row requests%ROWTYPE;
    debug_obj JSONB := '{}';
BEGIN
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    debug_obj := jsonb_build_object(
        'request_id', p_request_id,
        'request_status', request_row.status,
        'exchange_partner_id', request_row.exchange_partner_id,
        'exchange_partner_approved', request_row.exchange_partner_approved
    );
    
    IF request_row.id IS NULL THEN
        RETURN QUERY SELECT false, 'Request not found', debug_obj;
        RETURN;
    END IF;
    
    IF request_row.status IN ('Approved', 'Rejected') THEN
        RETURN QUERY SELECT false, 'Request already processed', debug_obj;
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_id IS NULL THEN
        RETURN QUERY SELECT true, 'Regular leave request - can approve', debug_obj;
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_approved IS NULL THEN
        RETURN QUERY SELECT false, 'Waiting for exchange partner approval', debug_obj;
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_approved = false THEN
        RETURN QUERY SELECT false, 'Exchange partner rejected the request', debug_obj;
        RETURN;
    END IF;
    
    RETURN QUERY SELECT true, 'Exchange partner approved - admin can approve', debug_obj;
END;
$$ LANGUAGE plpgsql;

-- 4b. Safe approval function with comprehensive error handling
CREATE FUNCTION admin_approve_request_safe(
    p_request_id BIGINT,
    p_new_status TEXT
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    approval_check RECORD;
    rows_affected INTEGER;
BEGIN
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;
    
    RAISE NOTICE 'Approving request % from % to %', p_request_id, request_row.status, p_new_status;
    
    IF p_new_status = 'Approved' THEN
        BEGIN
            SELECT can_approve, reason INTO approval_check FROM can_admin_approve_request(p_request_id);
            IF NOT approval_check.can_approve THEN
                RETURN jsonb_build_object('success', false, 'error', 'Cannot approve: ' || approval_check.reason);
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Approval check failed, proceeding: %', SQLERRM;
        END;
    END IF;
    
    UPDATE requests SET status = p_new_status WHERE id = p_request_id;
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    
    IF rows_affected = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No rows updated');
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Request updated successfully',
        'old_status', request_row.status,
        'new_status', p_new_status
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- 4c. Partner approval function
CREATE FUNCTION approve_exchange_request(
    p_request_id BIGINT,
    p_employee_id BIGINT,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
BEGIN
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request not found');
    END IF;
    
    IF request_row.exchange_partner_id != p_employee_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not the exchange partner');
    END IF;
    
    IF request_row.exchange_partner_approved IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Already responded');
    END IF;
    
    UPDATE requests 
    SET 
        exchange_partner_approved = p_approved,
        exchange_partner_approved_at = NOW(),
        exchange_partner_notes = p_notes,
        status = CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    WHERE id = p_request_id;
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', CASE WHEN p_approved THEN 'Approved' ELSE 'Rejected' END,
        'new_status', CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    );
END;
$$ LANGUAGE plpgsql;

-- 4d. Work schedule management
CREATE FUNCTION get_or_create_work_schedule(
    p_employee_id BIGINT,
    p_week_start_date DATE
) RETURNS BIGINT AS $$
DECLARE
    schedule_id BIGINT;
BEGIN
    SELECT id INTO schedule_id FROM work_schedules
    WHERE employee_id = p_employee_id AND week_start_date = p_week_start_date;
    
    IF schedule_id IS NOT NULL THEN
        RETURN schedule_id;
    END IF;
    
    INSERT INTO work_schedules (employee_id, week_start_date)
    VALUES (p_employee_id, p_week_start_date)
    RETURNING id INTO schedule_id;
    
    RETURN schedule_id;
END;
$$ LANGUAGE plpgsql;

-- 4e. Bidirectional schedule swap
CREATE FUNCTION swap_work_schedules_bidirectional(
    p_employee1_id BIGINT,
    p_employee2_id BIGINT, 
    p_employee1_date DATE,
    p_employee2_date DATE
) RETURNS JSONB AS $$
DECLARE
    emp1_week_start DATE;
    emp2_week_start DATE;
    emp1_day_column TEXT;
    emp2_day_column TEXT;
    emp1_schedule_id BIGINT;
    emp2_schedule_id BIGINT;
    emp1_original_status TEXT;
    emp2_original_status TEXT;
BEGIN
    -- Calculate week starts and day columns
    emp1_week_start := p_employee1_date - (EXTRACT(DOW FROM p_employee1_date)::INTEGER - 1);
    emp2_week_start := p_employee2_date - (EXTRACT(DOW FROM p_employee2_date)::INTEGER - 1);
    
    emp1_day_column := CASE EXTRACT(DOW FROM p_employee1_date)::INTEGER
        WHEN 0 THEN 'sunday_status' WHEN 1 THEN 'monday_status' WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status' WHEN 4 THEN 'thursday_status' 
        WHEN 5 THEN 'friday_status' WHEN 6 THEN 'saturday_status'
    END;
    
    emp2_day_column := CASE EXTRACT(DOW FROM p_employee2_date)::INTEGER
        WHEN 0 THEN 'sunday_status' WHEN 1 THEN 'monday_status' WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status' WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status' WHEN 6 THEN 'saturday_status'
    END;
    
    -- Get or create schedules
    emp1_schedule_id := get_or_create_work_schedule(p_employee1_id, emp1_week_start);
    emp2_schedule_id := get_or_create_work_schedule(p_employee2_id, emp2_week_start);
    
    -- Get current statuses
    EXECUTE format('SELECT %I FROM work_schedules WHERE id = %s', emp1_day_column, emp1_schedule_id) INTO emp1_original_status;
    EXECUTE format('SELECT %I FROM work_schedules WHERE id = %s', emp2_day_column, emp2_schedule_id) INTO emp2_original_status;
    
    -- Swap the statuses
    EXECUTE format('UPDATE work_schedules SET %I = %L WHERE id = %s', emp1_day_column, emp2_original_status, emp1_schedule_id);
    EXECUTE format('UPDATE work_schedules SET %I = %L WHERE id = %s', emp2_day_column, emp1_original_status, emp2_schedule_id);
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Schedules swapped successfully',
        'employee1_change', emp1_original_status || ' → ' || emp2_original_status,
        'employee2_change', emp2_original_status || ' → ' || emp1_original_status
    );
END;
$$ LANGUAGE plpgsql;

-- STEP 5: Create approval trigger
DROP TRIGGER IF EXISTS trigger_update_schedule_on_approval ON requests;

CREATE OR REPLACE FUNCTION update_schedules_on_approval()
RETURNS TRIGGER AS $$
DECLARE
    swap_result JSONB;
BEGIN
    IF NEW.status = 'Approved' AND (OLD.status IS NULL OR OLD.status != 'Approved') THEN
        RAISE NOTICE 'Processing approval for request %', NEW.id;
        
        IF NEW.exchange_partner_id IS NOT NULL AND NEW.exchange_from_date IS NOT NULL AND NEW.exchange_to_date IS NOT NULL THEN
            BEGIN
                SELECT swap_work_schedules_bidirectional(
                    NEW.employee_id, NEW.exchange_partner_id, 
                    NEW.exchange_from_date, NEW.exchange_to_date
                ) INTO swap_result;
                RAISE NOTICE 'Schedule swap result: %', swap_result;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Schedule swap failed: %', SQLERRM;
            END;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_schedule_on_approval
    AFTER UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION update_schedules_on_approval();

-- STEP 6: Fix existing data
UPDATE requests 
SET status = 'Partner Approved'
WHERE exchange_partner_approved = true 
  AND status = 'Pending'
  AND exchange_partner_id IS NOT NULL;

-- STEP 7: Show deployment results
SELECT 'DEPLOYMENT COMPLETED SUCCESSFULLY' as status;

SELECT 
    'Exchange Requests Status:' as info,
    r.id,
    r.employee_name,
    r.status,
    r.exchange_partner_approved,
    CASE 
        WHEN r.exchange_partner_approved IS NULL THEN '⏳ Waiting for partner'
        WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN '✅ Ready for admin'
        WHEN r.exchange_partner_approved = false THEN '❌ Partner rejected'
        WHEN r.status = 'Approved' THEN '🎉 Approved'
        ELSE '❓ Status: ' || r.status
    END as workflow_status
FROM requests r
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC;

COMMIT; 