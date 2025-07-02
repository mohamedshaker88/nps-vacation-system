-- Combined Bidirectional Exchange Fix
-- Run this in your database to enable true two-way exchange

-- 1. Bidirectional swap function
CREATE OR REPLACE FUNCTION swap_work_schedules_bidirectional(
    p_employee1_id BIGINT,
    p_employee2_id BIGINT, 
    p_employee1_date DATE,  -- Date employee1 wants to have off
    p_employee2_date DATE   -- Date employee2 wants to have off
) RETURNS JSONB AS $$
DECLARE
    emp1_week_start DATE;
    emp2_week_start DATE;
    emp1_day_of_week INTEGER;
    emp2_day_of_week INTEGER;
    emp1_day_column VARCHAR(20);
    emp2_day_column VARCHAR(20);
    emp1_schedule_id BIGINT;
    emp2_schedule_id BIGINT;
    emp1_original_status VARCHAR(20);
    emp2_original_status VARCHAR(20);
    result JSONB;
BEGIN
    -- Calculate week start dates (Monday = 1)
    emp1_day_of_week := EXTRACT(DOW FROM p_employee1_date);
    emp2_day_of_week := EXTRACT(DOW FROM p_employee2_date);
    
    -- Convert Sunday (0) to 7 for proper calculation
    IF emp1_day_of_week = 0 THEN emp1_day_of_week := 7; END IF;
    IF emp2_day_of_week = 0 THEN emp2_day_of_week := 7; END IF;
    
    emp1_week_start := p_employee1_date - (emp1_day_of_week - 1);
    emp2_week_start := p_employee2_date - (emp2_day_of_week - 1);
    
    -- Get day column names
    emp1_day_column := CASE emp1_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    emp2_day_column := CASE emp2_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    -- Get or create work schedules
    emp1_schedule_id := get_or_create_work_schedule(p_employee1_id, emp1_week_start);
    emp2_schedule_id := get_or_create_work_schedule(p_employee2_id, emp2_week_start);
    
    -- Get current statuses
    EXECUTE format('SELECT %I FROM work_schedules WHERE id = $1', emp1_day_column)
    INTO emp1_original_status
    USING emp1_schedule_id;
    
    EXECUTE format('SELECT %I FROM work_schedules WHERE id = $1', emp2_day_column)
    INTO emp2_original_status
    USING emp2_schedule_id;
    
    -- Perform the bidirectional swap
    EXECUTE format('UPDATE work_schedules SET %I = $1 WHERE id = $2', emp1_day_column)
    USING emp2_original_status, emp1_schedule_id;
    
    EXECUTE format('UPDATE work_schedules SET %I = $1 WHERE id = $2', emp2_day_column)
    USING emp1_original_status, emp2_schedule_id;
    
    -- Build result
    result := jsonb_build_object(
        'success', true,
        'employee1_id', p_employee1_id,
        'employee2_id', p_employee2_id,
        'employee1_date', p_employee1_date,
        'employee2_date', p_employee2_date,
        'employee1_change', emp1_original_status || ' → ' || emp2_original_status,
        'employee2_change', emp2_original_status || ' → ' || emp1_original_status,
        'message', 'Bidirectional exchange completed successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 2. Update the admin approval trigger to use bidirectional swap
CREATE OR REPLACE FUNCTION update_request_status_and_schedules_bidirectional()
RETURNS TRIGGER AS $$
DECLARE
    partner_employee employees%ROWTYPE;
    requester_employee employees%ROWTYPE;
    swap_result JSONB;
BEGIN
    -- Only process when status changes to 'Approved'
    IF NEW.status = 'Approved' AND OLD.status != 'Approved' THEN
        -- If this is an exchange request, perform bidirectional swap
        IF NEW.exchange_partner_id IS NOT NULL AND NEW.exchange_from_date IS NOT NULL AND NEW.exchange_to_date IS NOT NULL THEN
            -- Get employee details
            SELECT * INTO requester_employee FROM employees WHERE id = NEW.employee_id;
            SELECT * INTO partner_employee FROM employees WHERE id = NEW.exchange_partner_id;
            
            -- Perform bidirectional schedule swap
            SELECT swap_work_schedules_bidirectional(
                NEW.employee_id,           -- Requester
                NEW.exchange_partner_id,   -- Partner  
                NEW.exchange_from_date,    -- Date requester wants off
                NEW.exchange_to_date       -- Date partner wants off
            ) INTO swap_result;
            
            -- Create detailed notifications for both parties
            INSERT INTO notifications (employee_id, type, title, message, is_read) VALUES
            (NEW.employee_id, 'exchange_approved', 
             'Exchange Request Approved', 
             format('✅ Your exchange request approved! You now have OFF on %s and WORK on %s. %s has OFF on %s and WORKS on %s.',
                    NEW.exchange_from_date,
                    NEW.exchange_to_date,
                    partner_employee.name,
                    NEW.exchange_to_date,
                    NEW.exchange_from_date),
             false),
            (NEW.exchange_partner_id, 'exchange_approved', 
             'Exchange Request Approved', 
             format('✅ Exchange with %s approved! You now have OFF on %s and WORK on %s. %s has OFF on %s and WORKS on %s.',
                    requester_employee.name,
                    NEW.exchange_to_date,
                    NEW.exchange_from_date,
                    requester_employee.name,
                    NEW.exchange_from_date,
                    NEW.exchange_to_date),
             false);
             
            -- Log the swap result
            RAISE NOTICE 'Bidirectional exchange completed: %', swap_result;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Replace the trigger
DROP TRIGGER IF EXISTS trigger_update_schedule_on_approval ON requests;
CREATE TRIGGER trigger_update_schedule_on_approval
    AFTER UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION update_request_status_and_schedules_bidirectional();

-- 4. Fix partner approval status
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
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', CASE WHEN p_approved THEN 'Request approved successfully' ELSE 'Request rejected' END,
        'new_status', CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END
    );
END;
$$ LANGUAGE plpgsql;

-- 5. Show current exchange status
SELECT 
    'Exchange Requests Status:' as info,
    r.id,
    r.employee_name as requester,
    e.name as partner,
    r.status,
    r.exchange_from_date,
    r.exchange_to_date,
    r.exchange_partner_approved,
    CASE 
        WHEN r.exchange_partner_approved IS NULL THEN '⏳ Waiting for partner'
        WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN '✅ Ready for admin'
        WHEN r.exchange_partner_approved = false THEN '❌ Partner rejected'
        WHEN r.status = 'Approved' THEN '🎉 Approved & schedules swapped'
        ELSE '❓ Unknown status'
    END as workflow_status
FROM requests r
LEFT JOIN employees e ON e.id = r.exchange_partner_id
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC;

COMMIT; 