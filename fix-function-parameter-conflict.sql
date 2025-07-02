-- Fix Function Parameter Conflict
-- Drop and recreate the swap_work_schedules_bidirectional function with proper parameter names

BEGIN;

-- Step 1: Drop the existing function with all possible signatures
DROP FUNCTION IF EXISTS swap_work_schedules_bidirectional(bigint, bigint, date, date);
DROP FUNCTION IF EXISTS swap_work_schedules_bidirectional(p_employee1_id bigint, p_employee2_id bigint, p_employee1_desired_off_date date, p_employee2_desired_off_date date);

-- Step 2: Add the new field for partner's desired off day
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS partner_desired_off_date DATE;

-- Add comment for documentation
COMMENT ON COLUMN requests.partner_desired_off_date IS 'The date the exchange partner wants to have off (will become the requester working day)';

-- Step 3: Create the new bidirectional swap function with proper parameter names
CREATE OR REPLACE FUNCTION swap_work_schedules_bidirectional(
    p_requester_id BIGINT,
    p_partner_id BIGINT, 
    p_requester_desired_off_date DATE,  -- Date requester wants off
    p_partner_desired_off_date DATE     -- Date partner wants off
) RETURNS JSONB AS $$
DECLARE
    requester_name VARCHAR(255);
    partner_name VARCHAR(255);
    requester_off_week DATE;
    partner_off_week DATE;
    requester_off_schedule_id BIGINT;
    partner_off_schedule_id BIGINT;
    requester_off_day_column VARCHAR(20);
    partner_off_day_column VARCHAR(20);
    requester_off_day_of_week INTEGER;
    partner_off_day_of_week INTEGER;
    result JSONB;
BEGIN
    -- Get employee names
    SELECT name INTO requester_name FROM employees WHERE id = p_requester_id;
    SELECT name INTO partner_name FROM employees WHERE id = p_partner_id;
    
    -- Validate the exchange makes sense (both dates should be in the future)
    IF p_requester_desired_off_date <= CURRENT_DATE OR p_partner_desired_off_date <= CURRENT_DATE THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Exchange dates must be in the future',
            'requester_desired_off_date', p_requester_desired_off_date,
            'partner_desired_off_date', p_partner_desired_off_date
        );
    END IF;
    
    -- Calculate day of week and week start for both dates
    requester_off_day_of_week := EXTRACT(DOW FROM p_requester_desired_off_date);
    partner_off_day_of_week := EXTRACT(DOW FROM p_partner_desired_off_date);
    
    -- Convert Sunday (0) to 7 for proper calculation
    IF requester_off_day_of_week = 0 THEN requester_off_day_of_week := 7; END IF;
    IF partner_off_day_of_week = 0 THEN partner_off_day_of_week := 7; END IF;
    
    -- Calculate week start dates (Monday)
    requester_off_week := p_requester_desired_off_date - (requester_off_day_of_week - 1);
    partner_off_week := p_partner_desired_off_date - (partner_off_day_of_week - 1);
    
    -- Get day column names
    requester_off_day_column := CASE requester_off_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    partner_off_day_column := CASE partner_off_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    -- Get or create work schedules
    requester_off_schedule_id := get_or_create_work_schedule(p_requester_id, requester_off_week);
    partner_off_schedule_id := get_or_create_work_schedule(p_partner_id, partner_off_week);
    
    -- BIDIRECTIONAL SWAP:
    -- 1. Requester gets OFF on their desired date
    EXECUTE format('UPDATE work_schedules SET %I = ''off'' WHERE id = $1', requester_off_day_column)
    USING requester_off_schedule_id;
    
    -- 2. Partner gets OFF on their desired date  
    EXECUTE format('UPDATE work_schedules SET %I = ''off'' WHERE id = $1', partner_off_day_column)
    USING partner_off_schedule_id;
    
    -- 3. Cross-coverage: Each person works on the other's desired off date
    -- Handle different weeks scenario
    IF partner_off_week != requester_off_week THEN
        -- Different weeks - need separate schedule updates
        DECLARE
            requester_partner_week_schedule_id BIGINT;
            partner_requester_week_schedule_id BIGINT;
        BEGIN
            -- Requester works on partner's desired off date (in partner's week)
            requester_partner_week_schedule_id := get_or_create_work_schedule(p_requester_id, partner_off_week);
            EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', partner_off_day_column)
            USING requester_partner_week_schedule_id;
            
            -- Partner works on requester's desired off date (in requester's week)
            partner_requester_week_schedule_id := get_or_create_work_schedule(p_partner_id, requester_off_week);
            EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', requester_off_day_column)
            USING partner_requester_week_schedule_id;
        END;
    ELSE
        -- Same week - both changes in same schedules
        -- Requester works on partner's day
        EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', partner_off_day_column)
        USING requester_off_schedule_id;
        
        -- Partner works on requester's day
        EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', requester_off_day_column)
        USING partner_off_schedule_id;
    END IF;
    
    result := jsonb_build_object(
        'success', true,
        'requester_name', requester_name,
        'partner_name', partner_name,
        'requester_gets_off_on', p_requester_desired_off_date,
        'partner_gets_off_on', p_partner_desired_off_date,
        'summary', format('SUCCESS: %s gets off on %s, %s gets off on %s. Both cover each other''s shifts.',
                         requester_name, p_requester_desired_off_date,
                         partner_name, p_partner_desired_off_date)
    );
    
    RAISE NOTICE 'Bidirectional exchange completed: %', result->>'summary';
    
    RETURN result;
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Database error during schedule swap',
        'details', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Step 4: Update admin approval function to use the new bidirectional structure
CREATE OR REPLACE FUNCTION admin_approve_request_safe(p_request_id BIGINT)
RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    requester_employee employees%ROWTYPE;
    partner_employee employees%ROWTYPE;
    swap_result JSONB;
BEGIN
    -- Get the request details
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Validate request exists
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request not found');
    END IF;
    
    -- Check if admin can approve this request
    IF request_row.status != 'Partner Approved' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request is not ready for admin approval');
    END IF;
    
    -- Get employee details
    SELECT * INTO requester_employee FROM employees WHERE id = request_row.employee_id;
    SELECT * INTO partner_employee FROM employees WHERE id = request_row.exchange_partner_id;
    
    -- For exchange requests with partner_desired_off_date
    IF request_row.exchange_partner_id IS NOT NULL AND request_row.partner_desired_off_date IS NOT NULL THEN
        -- Perform bidirectional schedule swap using proper dates
        swap_result := swap_work_schedules_bidirectional(
            request_row.employee_id,                    -- Requester
            request_row.exchange_partner_id,            -- Partner
            request_row.exchange_to_date,               -- Date requester wants off
            request_row.partner_desired_off_date        -- Date partner wants off
        );
        
        IF NOT (swap_result->>'success')::boolean THEN
            RETURN jsonb_build_object(
                'success', false, 
                'message', 'Failed to update work schedules',
                'error', swap_result->>'error'
            );
        END IF;
    END IF;
    
    -- Update request status to Approved
    UPDATE requests SET status = 'Approved' WHERE id = p_request_id;
    
    -- Create success notifications for both parties
    INSERT INTO notifications (employee_id, type, title, message, is_read) VALUES
    (request_row.employee_id, 'exchange_approved', 
     'Exchange Request Approved', 
     format('✅ Your exchange request approved! You have OFF on %s. %s has OFF on %s. Schedules updated automatically.',
            request_row.exchange_to_date,
            partner_employee.name,
            request_row.partner_desired_off_date),
     false),
    (request_row.exchange_partner_id, 'exchange_completed',
     'Exchange Schedule Updated', 
     format('✅ Exchange completed! You have OFF on %s. %s has OFF on %s. Thank you for your cooperation!',
            request_row.partner_desired_off_date,
            requester_employee.name, 
            request_row.exchange_to_date),
     false);
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Exchange request approved and schedules updated',
        'swap_details', swap_result
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', 'Database error occurred',
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Show success message
SELECT 'SUCCESS: Function parameter conflict resolved! Bidirectional exchange system ready.' as status; 